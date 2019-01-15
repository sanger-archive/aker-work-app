require 'rails_helper'

RSpec.describe :plan_update_service do
  let(:user_and_groups) { ['user@sanger.ac.uk', 'world'] }
  let(:messages) { {} }
  let(:params) { {} }
  let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0]) }
  let(:service) do
    ps = PlanUpdateService.new(params, plan, user_and_groups, messages)
    allow(ps).to receive(:helper).and_return helper
    ps
  end
  let(:unit_price) { 11 }
  let(:helper) do
    h = instance_double("PlanHelper")
    allow(h).to receive(:check_product_options).and_return true
    allow(h).to receive(:validate_project_selection).and_return true
    allow(h).to receive(:validate_data_release_strategy_selection).and_return true
    allow(h).to receive(:check_set_contents).and_return true
    allow(h).to receive(:predict_unit_price).and_return unit_price
    allow(h).to receive(:create_module_choices).and_return true
    h
  end
  let(:product) do
    prod = create(:product)
    processes = [1,2,3].map { |n| create(:process, name: "pro-#{n}") }
    processes.each_with_index { |pro,i| create(:product_process, product: prod, aker_process: pro, stage: i) }
    prod.reload
  end
  let(:modules) do
    mods = ['alpha', 'beta', 'gamma'].map { create(:process_module) }
    last = nil
    pro = product.processes.first
    (mods.map(&:id) + [nil]).each do |mid|
      create(:aker_process_module_pairings, aker_process_id: pro.id, from_step_id: last, to_step_id: mid, default_path: true)
      last = mid
    end
    mods
  end

  let(:data_release_strategy) { create(:data_release_strategy) }

  let(:set) { make_set(2, true) }

  let(:known_materials) do
    known_mats = {}
    allow(MatconClient::Material).to receive(:where) do |args|
      matids = args['_id']['$in']
      make_rs_response(matids.map { |id| known_mats[id] }.compact)
    end
    known_mats
  end

  before do
    setup
    @result = service.perform
  end

  def extra_setup
  end

  def setup
    stub_stamps
    extra_setup
  end

  describe 'selecting a set' do
    let(:params) { { original_set_uuid: set.id } }

    context 'when the set is suitable' do
      it 'should return true' do
        expect(@result).to be_truthy
      end

      it 'should have no errors' do
        expect(messages[:error]).to be_nil
      end

      it 'should have set the set id in the work plan' do
        expect(plan.reload.original_set_uuid).to eq(set.id)
      end
    end

    context 'when the plan already has a set selected' do
      let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0], original_set_uuid: SecureRandom.uuid) }
      it 'should return true' do
        expect(@result).to be_truthy
      end

      it 'should have no errors' do
        expect(messages[:error]).to be_nil
      end

      it 'should have set the new set id in the work plan' do
        expect(plan.reload.original_set_uuid).to eq(set.id)
      end
    end

    context 'when the set contents are not permitted' do
      def extra_setup
        allow(helper).to receive(:check_set_contents).with(set.id) do
          messages[:error] = "The set contents were wrong."
          false
        end
      end

      it 'should return false' do
        expect(@result).to be_falsey
      end

      it 'should have the error message from the helper' do
        expect(messages[:error]).to eq "The set contents were wrong."
      end

      it 'should not have set the new set id in the work plan' do
        expect(plan.reload.original_set_uuid).to be_nil
      end
    end

  end

  describe 'selecting a project id' do
    let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0], original_set_uuid: set.id) }
    let(:project_id) { 20 }
    let(:params) { { project_id: project_id } }

    context 'when the project is set successfully' do
      it 'should return true' do
        expect(@result).to be_truthy
      end

      it 'should have no errors' do
        expect(messages[:error]).to be_nil
      end

      it 'should have set the project id in the work plan' do
        expect(plan.reload.project_id).to eq(project_id)
      end

      it 'should not have set the estimated cost on the plan' do
        expect(plan.reload.estimated_cost).to be_nil
      end
    end

    context 'when the plan has a product and options already selected' do
      let(:plan) do
        wp = WorkPlan.create!(owner_email: user_and_groups[0], original_set_uuid: set.id, project_id: 10, product_id: product.id)
        choose_modules(wp, modules)
        wp
      end

      it 'should return true' do
        expect(@result).to be_truthy
      end

      it 'should have no errors' do
        expect(messages[:error]).to be_nil
      end

      it 'should have set the project id in the work plan' do
        expect(plan.reload.project_id).to eq(project_id)
      end

      it 'should have set the estimated cost on the plan' do
        expect(plan.reload.estimated_cost).to eq(unit_price * set.meta[:size])
      end
    end

    context 'when the project is not compatible with the modules' do
      let(:plan) do
        wp = WorkPlan.create!(owner_email: user_and_groups[0], original_set_uuid: set.id, project_id: 10, product_id: product.id)
        choose_modules(wp, modules)
        wp
      end

      def extra_setup
        allow(helper).to receive(:predict_unit_price) do |project_id, module_names|
          messages[:error] = "Some kind of problem."
          false
        end
      end

      it 'should return false' do
        expect(@result).to be_falsey
      end

      it 'should have the error message from the helper' do
        expect(messages[:error]).to eq "Some kind of problem."
      end

      it 'should call predict_unit_price with the correct arguments' do
        expect(helper).to have_received(:predict_unit_price).with(project_id, modules.map(&:name))
      end

      it 'should not change the project_id' do
        expect(plan.project_id).to eq(10)
      end
    end

    context 'when the plan is active' do
      def extra_setup
        allow(plan).to receive(:status).and_return 'active'
      end

      it 'should return false' do
        expect(@result).to be_falsey
      end

      it 'should have an appropriate error message' do
        expect(messages[:error]).to eq "This work plan cannot be updated."
      end

      it 'should not change the project_id' do
        expect(plan.project_id).to be_nil
      end
    end
  end

  describe 'selecting a data release strategy' do
    let(:params) { { data_release_strategy_id: data_release_strategy.id } }
    let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0], original_set_uuid: set.id, project_id: 10, product_id: product.id) }

    context 'when the data release strategy is allowed' do
      it 'should return true' do
        expect(@result).to be_truthy
      end

      it 'should not have any errors' do
        expect(messages[:error]).to be_nil
      end

      it 'should set the data release strategy in the work plan' do
        expect(plan.reload.data_release_strategy).to eq(data_release_strategy)
      end
    end

    context 'when the data release strategy is disallowed' do
      def extra_setup
        allow(helper).to receive(:validate_data_release_strategy_selection) do |drsid|
          messages[:error] = "Poor strategy."
          false
        end
      end

      it 'should return false' do
        expect(@result).to be_falsey
      end

      it 'should have the error from the helper' do
        expect(messages[:error]).to eq "Poor strategy."
      end

      it 'should not set the data release strategy in the work plan' do
        expect(plan.reload.data_release_strategy).to be_nil
      end

      it 'should attempt to validate the data release strategy' do
        expect(helper).to have_received(:validate_data_release_strategy_selection).with(data_release_strategy.id)
      end
    end

  end

  describe 'specifying the product' do

    let(:params) do
      a,b,c = modules.map(&:id)
      { product_id: product.id, product_options: "[[#{a},#{b}],[#{c}],[]]", work_order_modules: {c.to_s => { selected_value: 5 }} }
    end

    let(:process_modids) do
      a,b,c = modules.map(&:id)
      [[a,b], [c], []]
    end

    let(:process_values) { [[nil,nil], [5], []] }

    let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0], original_set_uuid: set.id, project_id: 10) }

    context 'when the specification is allowed' do
      it 'should return true' do
        expect(@result).to be_truthy
      end

      it 'should have no errors' do
        expect(messages[:error]).to be_nil
      end

      it 'should have set the product in the plan' do
        expect(plan.product_id).to eq(product.id)
      end

      it 'should have updated the cost of the plan' do
        expect(plan.estimated_cost).to eq(set.meta[:size]*unit_price)
      end

      it 'should have set the modules for the plan' do
        product.processes.zip(process_modids, process_values).each do |pro, modids, values|
          expect(helper).to have_received(:create_module_choices).with(plan, pro, modids, values)
        end
      end
    end

    context 'when the options are invalid for the product' do
      def extra_setup
        allow(helper).to receive(:check_product_options) do |prod, prod_opts, values|
          messages[:error] = "Bad options."
          false
        end
      end

      it 'should return false' do
        expect(@result).to be_falsey
      end

      it 'should have the error from the helper' do
        expect(messages[:error]).to eq "Bad options."
      end

      it 'should not have set the product in the plan' do
        expect(plan.product_id).to be_nil
      end

      it 'should not have updated the cost of the plan' do
        expect(plan.estimated_cost).to be_nil
      end

      it 'should have checked the product options' do
        expect(helper).to have_received(:check_product_options).with(product, process_modids, process_values)
      end

      it 'should not have set the modules for the plan' do
        expect(helper).not_to have_received(:create_module_choices)
      end
    end

    context 'when there is no valid price' do
      def extra_setup
        allow(helper).to receive(:predict_unit_price) do |project_id, module_names|
          messages[:error] = "No price."
          nil
        end
      end

      it 'should return false' do
        expect(@result).to be_falsey
      end

      it 'should have the error from the helper' do
        expect(messages[:error]).to eq "No price."
      end

      it 'should not have set the product in the plan' do
        expect(plan.product_id).to be_nil
      end

      it 'should not have updated the cost of the plan' do
        expect(plan.estimated_cost).to be_nil
      end

      it 'should have tried to predict the unit price' do
        expect(helper).to have_received(:predict_unit_price).with(plan.project_id, modules.map(&:name))
      end

      it 'should not have set the modules for the plan' do
        expect(helper).not_to have_received(:create_module_choices)
      end
    end

    context 'when previous options are replaced' do
      let(:plan) do
        wp = WorkPlan.create!(owner_email: user_and_groups[0], original_set_uuid: set.id, project_id: 10, product_id: product.id)
        choose_modules(wp, modules)
        @old_choices = wp.reload.process_module_choices.to_a
        wp
      end

      it 'should return true' do
        expect(@result).to be_truthy
      end

      it 'should have no errors' do
        expect(messages[:error]).to be_nil
      end

      it 'should have set the product in the plan' do
        expect(plan.product_id).to eq(product.id)
      end

      it 'should have updated the cost of the plan' do
        expect(plan.estimated_cost).to eq(set.meta[:size]*unit_price)
      end

      it 'should have deleted the old choices' do
        @old_choices.each { |choice| expect(choice).to be_destroyed }
      end

      it 'should have set the modules for the plan' do
        product.processes.zip(process_modids, process_values).each do |pro, modids, values|
          expect(helper).to have_received(:create_module_choices).with(plan, pro, modids, values)
        end
      end
    end
  end


  # helper functions:

  def choose_modules(plan, modules)
    pro = plan.product.processes.first
    modules.each_with_index { |mod,i| create(:process_module_choice, work_plan: plan, aker_process: pro, process_module: mod, position: i) }
  end

  def stub_stamps
    allow(StampClient::Permission).to receive(:check_catch).and_return true
  end

  def make_set(size=1, available=true)
    uuid = SecureRandom.uuid
    set = double(:set, id: uuid, uuid: uuid, name: "Set #{uuid}", locked: false, meta: { size: size })

    if size==0
      matids = []
      set_materials = double(:set_materials, materials: [])
    else
      matids = (0...size).map { SecureRandom.uuid }
      set_content_materials = matids.map { |matid| double(:material, id: matid) }
      set_materials = double(:set_materials, materials: set_content_materials)
      materials = matids.map { |matid| double(:material, id: matid, attributes: { 'available' => available }) }

      materials.each { |material| known_materials[material.id] = material }
    end

    allow(SetClient::Set).to receive(:find_with_materials).with(uuid).and_return([set_materials])
    allow(SetClient::Set).to receive(:find).with(uuid).and_return([set])
    allow(set).to receive(:_material_uuids).and_return(matids)
    set
  end

  def make_rs_response(items)
    result_set = double(:result_set, to_a: items.to_a, has_next?: false)
    return double(:response, result_set: result_set)
  end
end