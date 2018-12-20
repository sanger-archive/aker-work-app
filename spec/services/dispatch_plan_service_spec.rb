require 'rails_helper'

RSpec.describe :dispatch_plan_service do
  let(:user_and_groups) { ['user@sanger.ac.uk', 'world'] }
  let(:messages) { {} }
  let(:plan) do
    pl = WorkPlan.create!(owner_email: user_and_groups[0], product: product, original_set_uuid: set.id, project_id: 12, data_release_strategy_id: 5)
    selected_module_ids.each_with_index do |mid, i|
      create(:process_module_choice, work_plan_id: pl.id, aker_process_id: product.processes.first.id, aker_process_module_id: mid, position: i, selected_value: (i==1 ? 5 : nil))
    end
    pl
  end

  let(:selected_module_ids) { modules.map(&:id) }

  let(:plan_unit_price) { BigDecimal.new('1000') }

  let(:product_available?) { true }

  let(:product) do
    prod = create(:product, availability: product_available?)
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

  let(:set) { make_set(2, true) }

  let(:helper) do
    h = instance_double("PlanHelper")
    allow(h).to receive(:authorize_project).and_return true
    allow(h).to receive(:validate_data_release_strategy_selection).and_return true
    allow(h).to receive(:check_set_contents).and_return true
    allow(h).to receive(:check_broker).and_return true
    allow(h).to receive(:parent_cost_code).and_return 'S1234'
    allow(h).to receive(:predict_unit_price).and_return plan_unit_price
    h
  end

  let(:dispatcher) do
    d = instance_double('WorkOrderDispatcher')
    allow(d).to receive(:dispatch).and_return true
    d
  end

  let(:splitter) do
    s = instance_double('WorkOrderSplitter')
    allow(s).to receive(:split).and_return true
    s
  end

  let(:service) do
    ser = DispatchPlanService.new(plan, user_and_groups, messages)
    allow(ser).to receive(:helper).and_return helper
    allow(ser).to receive(:work_order_dispatcher).and_return dispatcher
    allow(ser).to receive(:work_order_splitter).and_return splitter
    ser
  end

  let(:unit_prices) { { 'alpha'=> BigDecimal.new('10'), 'beta' => BigDecimal.new('15'), 'gamma' => BigDecimal.new('75') } }

  before do
    allow(UbwClient).to receive(:get_unit_prices) do |module_names, cost_code|
      unit_prices.select { |k,v| module_names.include? k }
    end
  end

  # When the operation fails:
  #  * it should return false
  #  * there should be an error message as specified
  #  * no work orders should have been created
  RSpec::Matchers.define :dps_fail_with_error do |error|
    match { |result| !result && match_or_eq(messages[:error], error) && plan.reload.work_orders.empty? }

    failure_message do |result|
      if result
        "expected falsey result but got: #{result}"
      elsif !match_or_eq(messages[:error], error)
        "expected error message matching #{error} but got: #{messages[:error] || 'nil'}"
      elsif !plan.reload.work_orders.empty?
        "expected no orders to be created"
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

  context 'when the work plan is already underway' do
    before do
      create(:work_order, work_plan: plan, process: product.processes.first)
      plan.reload
    end

    it 'should fail with error /already underway/' do
      expect(service.perform).to be_falsey
      expect(messages[:error]).to match /already underway/
      expect(plan.reload.work_orders.size).to eq(1)
    end
  end

  context 'when the plan has no set' do
    let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0], product: product, project_id: 12) }
    it { expect(service.perform).to dps_fail_with_error(/No set/) }
  end

  context 'when the plan has no project' do
    let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0], product: product, original_set_uuid: set.id) }
    it { expect(service.perform).to dps_fail_with_error(/No project/) }
  end

  context 'when the plan has no product' do
    let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0], original_set_uuid: set.id, project_id: 12) }
    it { expect(service.perform).to dps_fail_with_error(/No product/) }
  end

  context 'when looking up the cost code fails' do
    it 'should fail with the error from the helper' do
      expect(helper).to receive(:parent_cost_code).with(plan.project_id) do
        messages[:error] = 'Bad project'
        false
      end
      expect(service.perform).to dps_fail_with_error 'Bad project'
    end
  end

  context 'when the project is not authorized' do
    it 'should fail with the error from the helper' do
      expect(helper).to receive(:authorize_project).with(plan.project_id) do
        messages[:error] = 'It was not allowed.'
        false
      end
      expect(service.perform).to dps_fail_with_error 'It was not allowed.'
    end
  end

  context 'when the data release strategy is not validated' do
    it 'should fail with the error from the helper' do
      expect(helper).to receive(:validate_data_release_strategy_selection).with(plan.data_release_strategy_id) do
        messages[:error] = 'Not strategic enough.'
        false
      end
      expect(service.perform).to dps_fail_with_error 'Not strategic enough.'
    end
  end

  context 'when the set contents fail the check' do
    it 'should fail with the error from the helper' do
      expect(helper).to receive(:check_set_contents).with(plan.original_set_uuid) do
        messages[:error] = 'Did not check out.'
        false
      end
      expect(service.perform).to dps_fail_with_error 'Did not check out.'
    end
  end

  context 'when the broker check fails' do
    it 'should fail with the error from the helper' do
      expect(helper).to receive(:check_broker) do
        messages[:error] = 'Broken.'
        false
      end
      expect(service.perform).to dps_fail_with_error 'Broken.'
    end
  end

  context 'when there are no modules selected' do
    let(:selected_module_ids) { [] }
    it { expect(service.perform).to dps_fail_with_error(/no modules/) }
  end

  context 'when the product is not available' do
    let(:product_available?) { false }
    it 'should fail with a notice' do
      expect(service.perform).to be_falsey
      expect(messages[:error]).to be_nil
      expect(messages[:notice]).to match(/product.*suspended/)
      expect(plan.reload.work_orders).to be_empty
    end
  end

  context 'when nothing goes wrong' do
    before do
      allow_any_instance_of(WorkOrder).to receive(:generate_dispatched_event) do |order, forwarded_jobs|
        @event_order = order
        @event_forwarded_jobs = forwarded_jobs
      end
      @result = service.perform
      @order = plan.reload.work_orders.first
    end

    it 'should return true' do
      expect(@result).to be_truthy
    end

    it 'should set the estimated cost on the plan' do
      expect(plan.estimated_cost).to eq(plan_unit_price * set.meta[:size])
    end

    it 'should create a suitable work order' do
      expect(plan.work_orders.size).to eq(1)
      expect(@order.process).to eq(product.processes.first)
      expect(@order.set_uuid).to eq(set.cloneset.uuid)
      expect(@order.cost_per_sample).to eq(BigDecimal.new('100')) # sum of the module costs
      expect(@order.total_cost).to eq(BigDecimal.new('200')) # multiplied by the set size
    end

    it 'should record the module choices for the work order' do
      choices = @order.work_order_module_choices.to_a
      expect(choices.map(&:process_module)).to eq(modules)
      expect(choices.map(&:selected_value)).to eq([nil, 5, nil])
    end

    it 'should split the order' do
      expect(splitter).to have_received(:split).with(@order)
    end

    it 'should have dispatched the order' do
      expect(dispatcher).to have_received(:dispatch).with(@order)
    end

    it 'should have tried to dispatch an event message with the correct arguments' do
      expect(@event_order).to eq(@order)
      expect(@event_forwarded_jobs).to be_empty
    end
  end

  # helpers

  def make_set(size=1, available=true)
    cuuid = SecureRandom.uuid
    cloneset = double(:set, id: cuuid, uuid: cuuid, name: "Locked set #{cuuid}", locked: true, meta: { size: size })

    uuid = SecureRandom.uuid
    set = double(:set, id: uuid, uuid: uuid, name: "Set #{uuid}", locked: false, meta: { size: size }, cloneset: cloneset)

    if size==0
      matids = []
      set_materials = double(:set_materials, materials: [])
    else
      matids = (0...size).map { SecureRandom.uuid }
      set_content_materials = matids.map { |matid| double(:material, id: matid) }
      set_materials = double(:set_materials, materials: set_content_materials)
    end

    allow(SetClient::Set).to receive(:find_with_materials).with(uuid).and_return([set_materials])
    allow(SetClient::Set).to receive(:find).with(uuid).and_return([set])

    allow(SetClient::Set).to receive(:find_with_materials).with(cuuid).and_return([set_materials])
    allow(SetClient::Set).to receive(:find).with(cuuid).and_return([cloneset])

    allow(set).to receive(:_material_uuids).and_return(matids)
    allow(cloneset).to receive(:_material_uuids).and_return(matids)
    allow(set).to receive(:create_locked_clone).and_return(cloneset)
    set
  end
end
