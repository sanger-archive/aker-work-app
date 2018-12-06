require 'rails_helper'

RSpec.describe :revise_options_service do
  let(:user_and_groups) { ['user@sanger.ac.uk', 'world'] }
  let(:messages) { {} }
  let(:plan) do
    pl = WorkPlan.create!(owner_email: user_and_groups[0], product: product, original_set_uuid: setuuid, project_id: 12)
    initial_module_ids.each_with_index do |mid, i|
      create(:process_module_choice, work_plan_id: pl.id, aker_process_id: process.id, aker_process_module_id: mid, position: i, selected_value: (i==1 ? 5 : nil))
    end
    pl.reload
  end

  let(:setuuid) { SecureRandom.uuid }
  let(:initial_module_ids) { [] }

  let(:product) do
    prod = create(:product)
    processes = [1,2,3].map { |n| create(:process, name: "pro-#{n}") }
    processes.each_with_index { |pro,i| create(:product_process, product: prod, aker_process: pro, stage: i) }
    prod.reload
  end

  let(:modules) do
    mods = ['alpha', 'beta', 'gamma'].map { |name| create(:process_module, name: name, min_value: (name=='beta' ? 1 : nil)) }
    last = nil
    pro = product.processes.first
    (mods.map(&:id) + [nil]).each do |mid|
      create(:aker_process_module_pairings, aker_process_id: pro.id, from_step_id: last, to_step_id: mid, default_path: true)
      last = mid
    end
    mods
  end

  let(:plan_unit_price) { BigDecimal.new('200') }

  let(:helper) do
    h = instance_double("PlanHelper")
    allow(h).to receive(:parent_cost_code).and_return 'S1234'
    allow(h).to receive(:modules_ok_for_process).and_return true
    allow(h).to receive(:module_values_ok).and_return true
    allow(h).to receive(:predict_unit_price).and_return plan_unit_price
    allow(h).to receive(:create_module_choices) { @create_module_choices_called = true }
    h
  end

  let(:process) { product.processes.first }
  let(:new_module_ids) { modules[0,1].map(&:id) }
  let(:new_values) { [nil, 17] }

  let(:service) do
    ros = ReviseOptionsService.new(plan, process.id, new_module_ids, new_values, user_and_groups, messages)
    allow(ros).to receive(:helper).and_return helper
    ros
  end

  # When the operation fails:
  #  * it should return false
  #  * there should be an error message as specified
  #  * modules should not have been destroyed
  #  * create_module_choices should not have been called
  RSpec::Matchers.define :fail_with_error do |error|
    match { |result| !result && match_or_eq(messages[:error], error) && plan.reload.process_module_choices.size==initial_module_ids.size && !@create_module_choices_called }

    failure_message do |result|
      if result
        "expected falsey result but got: #{result}"
      elsif !match_or_eq(messages[:error], error)
        "expected error message matching #{error} but got: #{messages[:error] || 'nil'}"
      elsif plan.process_module_choices.size!=initial_module_ids.size
        "expected module choices to be #{initial_module_ids} but it appears to be #{plan.process_module_choices.map(&:process_module_id)}"
      elsif @create_module_choices_called
        "expected create_module_choices not to have been called"
      else
        "failed for unknown reasons"
      end
    end
  end

  def match_or_eq(value, expected)
    if expected.is_a? String
      value==expected
    else
      expected.match? value
    end
  end

  context 'when the plan has no set' do
    let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0], product: product, project_id: 12) }

    it { expect(service.perform).to fail_with_error(/select a set/) }
  end

  context 'when the plan has no product' do
    let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0], original_set_uuid: setuuid, project_id: 12) }

    it { expect(service.perform).to fail_with_error(/no product/) }
  end

  context 'when the plan has no project' do
    let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0], product: product, original_set_uuid: setuuid) }

    it { expect(service.perform).to fail_with_error(/select a project/) }
  end

  context 'when the cost code cannot be determined' do
    it 'should fail with the error from the helper' do
      expect(helper).to receive(:parent_cost_code).with(plan.project_id) do
        messages[:error] = 'It cannot be judged.'
        nil
      end
      expect(service.perform).to fail_with_error('It cannot be judged.')
    end
  end

  context 'when the process is not part of the selected product' do
    let(:process) { create(:aker_process) }
    it { expect(service.perform).to fail_with_error(/process .* not .* product/) }
  end

  context 'when there are already work orders for the process' do
    let(:initial_module_ids) { modules.map(&:id) }
    before do
      create(:work_order, work_plan_id: plan.id, process_id: process.id)
      plan.reload
    end

    it { expect(service.perform).to fail_with_error(/already.*dispatched/) }
  end

  context 'when the modules are not suitable for the process' do
    let(:initial_module_ids) { modules.map(&:id) }
    it 'should fail with an appropriate error' do
      expect(helper).to receive(:modules_ok_for_process).with(new_module_ids, product.processes.first).and_return false
      expect(service.perform).to fail_with_error(/modules.*process/)
    end
  end

  context 'when the values are not suitable for the modules' do
    let(:initial_module_ids) { modules.map(&:id) }
    it 'should fail with an appropriate error' do
      expect(helper).to receive(:module_values_ok).with(new_module_ids, new_values).and_return false
      expect(service.perform).to fail_with_error(/values.*modules/)
    end
  end

  context 'when the modules cannot be priced' do
    let(:initial_module_ids) { modules.map(&:id) }
    it 'should fail with the error from the helper' do
      module_names = new_module_ids.map {|id| modules.find { |mod| mod.id==id }.name }
      expect(helper).to receive(:predict_unit_price).with(plan.project_id, module_names) do
        messages[:error] = 'I have no way of knowing.'
        false
      end
      expect(service.perform).to fail_with_error 'I have no way of knowing.'
    end
  end

  context 'when there are no such problems' do
    let(:initial_module_ids) { modules.map(&:id) }
    before do
      @result = service.perform
      plan.reload
    end

    it 'should return true' do
      expect(@result).to be_truthy
    end

    it 'should destroy the old modules' do
      expect(plan.process_module_choices).to be_empty
    end

    it 'should call create_module_choices' do
      expect(helper).to have_received(:create_module_choices).with(plan, process, new_module_ids, new_values)
    end
  end

end
