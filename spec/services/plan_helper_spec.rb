require 'rails_helper'

RSpec.describe :plan_helper do
  SEQUENCESCAPE_LIMS_ID = "SQSC"

  let(:user_and_groups) { ['user@sanger.ac.uk', 'world'] }
  let(:messages) { {} }
  let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0]) }

  let(:helper) { PlanHelper.new(plan, user_and_groups, messages) }

  let(:lims_id) { SEQUENCESCAPE_LIMS_ID }

  let(:product) do
    prod = create(:product, catalogue: create(:catalogue, lims_id: lims_id))
    processes = [1,2,3].map { |n| create(:process, name: "pro-#{n}") }
    processes.each_with_index { |pro,i| create(:product_process, product: prod, aker_process: pro, stage: i) }
    prod.reload
  end

  let(:project) { make_node(100, "S1234") }
  let(:subproject) { make_node(101, "S1234-0", project.id) }

  let(:known_materials) do
    known_mats = []
    allow(MatconClient::Material).to receive(:where) do |params|
      matids = params["_id"]["$in"]
      found = known_mats.select { |mat| matids.include? mat.id }
      result_set = double('result_set', has_next?: false, to_a: found)
      double('response', result_set: result_set)
    end
    known_mats
  end

  RSpec::Matchers.define :fail_with_error do |error|
    match do |result|
      if result
        false
      elsif error.is_a? String
        error==messages[:error]
      else
        error.match? messages[:error]
      end
    end

    failure_message do |result|
      if result
        "expected falsey result but got: #{result}"
      else
        "expected error message matching #{error} but got: #{messages[:error]}"
      end
    end
  end

  RSpec::Matchers.define :succeed_without_error do
    match do |result|
      result && !messages[:error]
    end

    failure_message do |result|
      if !result
        "expected truthy result but got: #{result || 'nil'}"
      else
        "unexpected error message: #{messages[:error]}"
      end
    end
  end

  describe '#validate_data_release_strategy_selection' do
    let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0], product: product) }
    context 'when the product is not from sequencescape' do
      let(:lims_id) { 'beep boop' }
      it { expect(helper.validate_data_release_strategy_selection(nil)).to succeed_without_error }
    end

    context 'when the strategy id is missing' do
      it { expect(helper.validate_data_release_strategy_selection('')).to fail_with_error(/No data release strategy/) }
      it { expect(helper.validate_data_release_strategy_selection(nil)).to fail_with_error(/No data release strategy/) }
    end

    context 'when the strategy id is invalid' do
      it { expect(helper.validate_data_release_strategy_selection(SecureRandom.uuid)).to fail_with_error(/No data release strategy.* found/) }
    end

    context 'when the strategy id is valid' do
      let(:strategy) { create(:data_release_strategy) }

      before do
        allow(DataReleaseStrategyClient).to receive(:find_strategies_by_user).with(user_and_groups[0]).and_return(found_strategies)
      end

      context 'when the strategy client finds a matching strategy' do
        let(:found_strategies) { [double('strategy', id: strategy.id)] }
        
        it { expect(helper.validate_data_release_strategy_selection(strategy.id)).to succeed_without_error }
      end
      context 'when the strategy client does not find a matching strategy' do
        let(:found_strategies) { [double('strategy', id: SecureRandom.uuid)] }
        
        it { expect(helper.validate_data_release_strategy_selection(strategy.id)).to fail_with_error(/cannot select/) }
      end
    end

  end

  describe '#parent_cost_code' do
    before do
      allow(StudyClient::Node).to receive(:find).and_return([])
    end

    context 'when the project id is invalid' do
      it { expect(helper.parent_cost_code(-1)).to fail_with_error(/No project.*found/) }
    end

    context 'when the node has no parent' do
      it { expect(helper.parent_cost_code(project.id)).to fail_with_error(/no parent project/) }
    end

    context 'when the parent node has no cost code' do
      let(:project) { make_node(100, nil) }
      it { expect(helper.parent_cost_code(subproject.id)).to fail_with_error(/no cost code/) }
    end

    context 'when the parent node has a cost code' do
      it 'should return the cost code with no errors' do
        expect(helper.parent_cost_code(subproject.id)).to eq(project.cost_code)
        expect(messages[:error]).to be_nil
      end
    end
  end

  describe '#validate_project_selection' do
    context 'when no project id is supplied' do
      it { expect(helper.validate_project_selection(nil)).to fail_with_error(/No project id/) }
      it { expect(helper.validate_project_selection('')).to fail_with_error(/No project id/) }
    end

    context 'when the parent cost code check fails' do
      it 'should call parent_cost_code and fail' do
        expect(helper).to receive(:parent_cost_code).with(10) do
          messages[:error] = "It was not correct."
          false
        end
        expect(helper.validate_project_selection(10)).to fail_with_error "It was not correct."
      end
    end

    context 'when the spend is not authorised' do
      it 'should fail with the error message from the exception' do
        expect(StudyClient::Node).to receive(:authorize!).and_raise(AkerPermissionGem::NotAuthorized, "It was not allowed.")
        expect(helper).to receive(:parent_cost_code).with(10).and_return true
        expect(helper.validate_project_selection(10)).to fail_with_error "It was not allowed."
      end
    end

    context 'when the spend is authorised' do
      it 'should fail with the error message from the exception' do
        expect(StudyClient::Node).to receive(:authorize!)
        expect(helper).to receive(:parent_cost_code).with(10).and_return true
        expect(helper.validate_project_selection(10)).to succeed_without_error
      end
    end
  end

  describe '#set_material_ids' do
    it 'should return the material ids from the set' do
      setid = SecureRandom.uuid
      matids = (0...3).map { SecureRandom.uuid }
      materials = matids.map { |matid| double('Material', id: matid) }
      set = double('Set', materials: materials)
      expect(SetClient::Set).to receive(:find_with_materials).with(setid).and_return([set]).once

      expect(helper.set_material_ids(setid)).to eq(matids)
      expect(helper.set_material_ids(setid)).to eq(matids)
    end
  end

  describe '#check_set_contents' do
    let(:materials) { make_materials([true, true, true]) }
    let(:setid) { SecureRandom.uuid }

    before do
      allow(helper).to receive(:set_material_ids).with(setid).and_return(materials.map(&:id))
    end

    context 'when the set is empty' do
      let(:materials) { [] }
      it { expect(helper.check_set_contents(setid)).to fail_with_error(/set.*empty/) }
    end

    context 'when some materials are unavailable' do
      let(:materials) { make_materials([true, false, true]) }
      it { expect(helper.check_set_contents(setid)).to fail_with_error(/materials.*not available/) }
    end

    context 'when the materials are not permitted' do
      it 'should fail with a suitable error' do
        badmid = materials.first.id
        expect(StampClient::Permission).to receive(:check_catch).with(
                        permission_type: :consume,
                        names: user_and_groups,
                        material_uuids: materials.map(&:id)
              ).and_return false
        expect(StampClient::Permission).to receive(:unpermitted_uuids).and_return([badmid])

        expect(helper.check_set_contents(setid)).to fail_with_error(/Not authori[sz]ed/)
        expect(messages[:error]).to include badmid
      end
    end

    context 'when the materials are permitted' do
      it 'should succeed without error' do
        expect(StampClient::Permission).to receive(:check_catch).with(
                        permission_type: :consume,
                        names: user_and_groups,
                        material_uuids: materials.map(&:id)
              ).and_return true
        expect(helper.check_set_contents(setid)).to succeed_without_error
      end
    end

  end

  describe '#predict_unit_price' do
    let(:project_id) { 15 }
    let(:module_names) { ['alpha', 'beta', 'gamma', 'beta'] }

    context 'when looking up the cost code fails' do
      it 'should fail with the error about the cost code' do
        expect(helper).to receive(:parent_cost_code).with(project_id) do
          messages[:error] = "Cost code bad."
          false
        end

        expect(helper.predict_unit_price(project_id, module_names)).to fail_with_error "Cost code bad."
      end
    end

    context 'when looking up the cost code succeeds' do
      let(:cost_code) { 'S1234' }
      let(:unit_prices) { { 'alpha' => BigDecimal.new('3.99'), 'beta' => BigDecimal.new('4.99'), 'gamma' => BigDecimal.new('100') } }

      before do
        allow(helper).to receive(:parent_cost_code).with(project_id).and_return cost_code
        allow(UbwClient).to receive(:get_unit_prices).with(module_names, cost_code).and_return(unit_prices)
      end

      context 'when no module names are suplied' do
        it { expect(helper.predict_unit_price(project_id, [])).to fail_with_error(/No module/) }
      end

      context 'when one unit price is missing' do
        let(:unit_prices) { super().except('beta') }

        it 'should fail with an appropriate error' do
          expect(helper.predict_unit_price(project_id, module_names)).to fail_with_error("The following module has no listed price for cost code #{cost_code}: #{['beta']}")
        end
      end

      context 'when multiple unit prices are missing' do
        let(:unit_prices) { {} }

        it 'should fail with an appropriate error' do
          expect(helper.predict_unit_price(project_id, module_names)).to fail_with_error("The following modules have no listed price for cost code #{cost_code}: #{module_names.uniq}")
        end
      end

      context 'when all prices are present' do
        it 'should return the total price' do
          expect(helper.predict_unit_price(project_id, module_names)).to eq(BigDecimal.new('113.97'))
          expect(messages[:error]).to be_nil
        end
      end
    end
  end

  describe '#modules_ok_for_process' do
    let(:process) { create(:aker_process) }
    let(:modules) do
      mods = (0...3).map { |i| create(:aker_process_module, aker_process: process, name: "MODULE #{i}") }
      last = nil
      (mods.map(&:id)+[nil]).each do |id|
        create(:aker_process_module_pairings, aker_process: process, from_step_id: last, to_step_id: id, default_path: true)
        last = id
      end
      mods
    end

    context 'when the module sequence is correct' do
      it { expect(helper.modules_ok_for_process(modules.map(&:id), process)).to be_truthy }
    end

    context' when the module sequence is incorrect' do
      it { expect(helper.modules_ok_for_process(modules.map(&:id).reverse, process)).to be_falsey }
    end
  end

  describe '#module_values_ok' do
    let(:process) { create(:aker_process) }
    let(:modules) do
      [
        create(:aker_process_module, aker_process: process, name: "MODULE 1"),
        create(:aker_process_module, aker_process: process, name: "MODULE 2", min_value: 10, max_value: 20)
      ]
    end

    context 'when the values are ok' do
      it { expect(helper.module_values_ok(modules.map(&:id), [nil, 15])).to be_truthy }
    end

    context 'when required values are nil' do
      it { expect(helper.module_values_ok(modules.map(&:id), [nil, nil])).to be_falsey }
    end

    context 'when values are out of bounds' do
      it { expect(helper.module_values_ok(modules.map(&:id), [nil, 5])).to be_falsey }
    end
  end

  describe '#check_product_options' do
    context 'when the arguments are of the wrong length' do
      it { expect(helper.check_product_options(product, [[],[],[]], [])).to fail_with_error(/modules.*do not match/) }
      it { expect(helper.check_product_options(product, [], [[],[],[]])).to fail_with_error(/modules.*do not match/) }
    end

    context 'when the modules are not ok for one of the processes' do
      it 'should fail with an appropriate error message' do
        processes = product.processes
        modids = [[1,2], [3,4], [5,6]]
        values = [[], [], []]
        allow(helper).to receive(:module_values_ok).and_return true

        expect(helper).to receive(:modules_ok_for_process).with([1,2], processes[0]).and_return true
        expect(helper).to receive(:modules_ok_for_process).with([3,4], processes[1]).and_return false

        expect(helper.check_product_options(product, modids, values)).to fail_with_error(/not .*valid .*process/)
        expect(messages[:error]).to include processes[1].name
      end
    end

    context 'when the values are not ok for one of the processes' do
      it 'should fail with an appropriate error message' do
        processes = product.processes
        modids = [[1,2], [3,4], [5,6]]
        values = [[100,200], [300,400], [500,600]]
        allow(helper).to receive(:modules_ok_for_process).and_return true

        expect(helper).to receive(:module_values_ok).with([1,2], [100,200]).and_return true
        expect(helper).to receive(:module_values_ok).with([3,4], [300,400]).and_return false

        expect(helper.check_product_options(product, modids, values)).to fail_with_error(/not .*valid .*process/)
        expect(messages[:error]).to include processes[1].name
      end
    end
  end

  describe '#create_module_choices' do
    let(:process) { product.processes.first }
    let(:modules) do
      [
        create(:aker_process_module, aker_process: process, name: "MODULE 1"),
        create(:aker_process_module, aker_process: process, name: "MODULE 2", min_value: 10, max_value: 20)
      ]
    end

    it 'should create the module choices' do
      helper.create_module_choices(plan, process, modules.map(&:id), [nil, 15])
      choices = plan.reload.process_module_choices.to_a
      expect(choices.map(&:aker_process_id).uniq).to eq([process.id])
      expect(choices.map(&:aker_process_module_id)).to eq(modules.map(&:id))
      expect(choices.map(&:selected_value)).to eq([nil, 15])
    end
  end

  describe '#get_node' do
    it 'should return nil for nil id' do
      expect(helper.get_node(nil)).to eq(nil)
    end

    it 'should find the node for the id' do
      node = double(:node, id: 15)
      expect(StudyClient::Node).to receive(:find).with(node.id).and_return([node]).once

      expect(helper.get_node(node.id)).to eq(node)
      expect(helper.get_node(node.id)).to eq(node)
    end
  end

  describe '#check_broker' do
    before do
      bd = class_double('BrokerHandle')
      stub_const('BrokerHandle', bd)
      allow(bd).to receive(:events_disabled?).and_return false
      allow(bd).to receive(:working?).and_return working?
    end

    context 'when the broker is working' do
      let(:working?) { true }
      it { expect(helper.check_broker).to succeed_without_error }
    end

    context 'when the broker is not working' do
      let(:working?) { false }
      it { expect(helper.check_broker).to fail_with_error("Could not connect to message exchange.") }
    end
  end

  # helper functions

  def make_node(id, cost_code, parent_id=nil)
    node = double(:project, id: id, name: "Project #{id}", cost_code: cost_code, parent_id: parent_id)
    allow(StudyClient::Node).to receive(:find).with(id).and_return([node])
    node
  end

  def make_materials(availability)
    mats = availability.map { |av| double(id: SecureRandom.uuid, attributes: { 'available' => av }) }
    known_materials.concat(mats)
    mats
  end
end
