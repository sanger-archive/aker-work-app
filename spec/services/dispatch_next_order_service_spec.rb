require 'rails_helper'

RSpec.describe :dispatch_next_order_service do
  RSpec::Matchers.define :fail_with_error do |error_expr|
    match { |result| !result && error_expr.match?(messages[:error]) && plan.reload.work_orders.size==2 }

    failure_message do |result|
      if result
        "expected falsey result but got: #{result}"
      elsif !error_expr.match?(messages[:error])
        "expected error message matching #{error} but got: #{messages[:error] || 'nil'}"
      elsif plan.reload.work_orders.size!=2
        "expected no new work orders to be created"
      else
        "failed for unknown reasons"
      end
    end
  end

  let(:messages) { {} }
  let(:user_and_groups) { ['user@sanger.ac.uk', 'world'] }
  let(:job_ids) { jobs.map(&:id) }

  let(:dispatcher) do
    disp = instance_double('WorkOrderDispatcher')
    allow(disp).to receive(:dispatch).and_return true
    disp
  end

  let(:splitter) do
    spl = instance_double('WorkOrderSplitter')
    allow(spl).to receive(:split).and_return true
    spl
  end

  let(:helper) { instance_double('PlanHelper') }

  let(:service) do
    ser = DispatchNextOrderService.new(job_ids, user_and_groups, messages)
    allow(ser).to receive(:work_order_dispatcher).and_return dispatcher
    allow(ser).to receive(:work_order_splitter).and_return splitter
    allow(ser).to receive(:helper).and_return helper
    ser
  end

  let(:plan) do
    wp = create(:work_plan, product_id: product.id, owner_email: user_and_groups[0], project_id: SecureRandom.uuid)
    pro = next_process
    modules.each_with_index do |mod, i|
      create(:process_module_choice, work_plan_id: wp.id, aker_process_id: pro.id,
              aker_process_module_id: mod.id, position: i)
    end
    wp
  end

  let(:product) do
    prod = create(:product)
    processes = [1,2,3].map { |n| create(:process, name: "pro-#{n}") }
    processes.each_with_index { |pro,i| create(:product_process, product: prod, aker_process: pro, stage: i) }
    prod.reload
  end

  let(:modules) do
    mods = ['alpha', 'beta'].map { |name| create(:process_module, name: name) }
    pro = next_process
    last = nil
    (mods.map(&:id) + [nil]).each do |id|
      create(:aker_process_module_pairings, to_step_id: id, from_step_id: last, default_path: true, aker_process: pro)
      last = id
    end
    mods
  end

  let(:previous_process) { product.processes[0] }
  let(:next_process) { product.processes[1]}

  let!(:orders) do
    [
      create(:work_order, work_plan: plan, process: previous_process),
      create(:work_order, work_plan: plan, process: previous_process),
    ]
  end

  let(:job_sets) { (0...2).map { set_double(2) } }

  let(:jobs) do
    orders.zip(job_sets, revised_sets).map do |order, set, revised_set|
      create(:job, work_order: order, input_set_uuid: set&.uuid, output_set_uuid: set&.uuid,
             revised_output_set_uuid: revised_set&.uuid, started: Time.now, completed: Time.now)
    end
  end

  let(:job_sets) { (0...2).map { set_double(2) } }
  let(:revised_sets) { [nil, set_double(job_sets.second._matids)] }

  let(:new_set) { set_double(4) }

  let(:known_sets) do
    known = {}
    allow(SetClient::Set).to receive(:find) { |setid| [known[setid]] }
    allow(helper).to receive(:set_material_ids) { |setid| known[setid]._matids }
    known
  end

  def set_double(matids)
    if matids.is_a? Integer
      size = matids
      matids = (0...size).map { SecureRandom.uuid }
    else
      size = matids.size
    end
    setid = SecureRandom.uuid
    set = double('Set', id: setid, uuid: setid, _matids: matids,
                 meta: {'size' => size}.with_indifferent_access, locked: false)
    allow(set).to receive(:update_attributes).and_return true
    allow(set).to receive(:set_materials)
    known_sets[setid] = set
  end

  before do
    allow(SetClient::Set).to receive(:create).and_return new_set
  end

  context 'when everything is valid' do
    before do
      @result = service.execute
      plan.reload
    end

    let(:new_order) { plan.work_orders.last }

    it { expect(@result).to be_truthy }

    it 'should have no errors' do
      expect(messages[:error]).to be_nil
    end

    it 'should have locked the revised output set' do
      revised_sets.compact.each { |rv| expect(rv).to have_received(:update_attributes).with(locked: true) }
    end

    it 'should have recorded that each job was forwarded' do
      jobs.each { |job| expect(job.reload).to be_forwarded }
    end

    it 'should have created a new work order' do
      expect(plan.work_orders.size).to eq(3)
    end

    it 'should have created a combined set' do
      expect(SetClient::Set).to have_received(:create).with(name: "Work Order #{new_order.id}")
    end

    it 'should have set the materials on the combined set' do
      expect(new_set).to have_received(:set_materials).with(job_sets[0]._matids + revised_sets[1]._matids)
    end

    it 'should have linked the new work order to a new set' do
      expect(new_order.set_uuid).to eq(new_set.id)
    end

    it 'should have linked the new order to chosen modules' do
      expect(new_order.process_modules.map(&:id)).to eq(modules.map(&:id))
    end

    it 'should have split the order' do
      expect(splitter).to have_received(:split).with(new_order)
    end

    it 'should have dispatched the order' do
      expect(dispatcher).to have_received(:dispatch).with(new_order)
    end

    it 'should have updated and locked the combined set' do
      expect(new_set).to have_received(:update_attributes).with(owner_id: plan.owner_email, locked: true)
    end
  end

  context 'when no job ids are supplied' do
    let(:job_ids) { [] }

    it { expect(service.execute).to fail_with_error(/No job ids/i) }
  end

  context 'when job ids are from different work plans' do
    let(:other_plan) { create(:work_plan, product_id: product.id, owner_email: user_and_groups[0]) }
    let(:other_order) { create(:work_order, work_plan: other_plan, process: previous_process) }
    let(:other_job) do
      set = set_double(2)
      create(:job, work_order: other_order, input_set_uuid: set.uuid, output_set_uuid: set.uuid,
              started: Time.now, completed: Time.now)
    end
    let(:job_ids) { [jobs[0], other_job].map(&:id) }

    it { expect(service.execute).to fail_with_error(/.*different.*plans/i) }
  end

  context 'when job ids are from different processes' do
    let!(:orders) do
      [
        create(:work_order, work_plan: plan, process: previous_process),
        create(:work_order, work_plan: plan, process: next_process),
      ]
    end

    it { expect(service.execute).to fail_with_error(/.*different.*processes/i) }
  end

  context 'when the jobs are from the last process in the product' do
    let(:previous_process) { product.processes.last }

    it { expect(service.execute).to fail_with_error(/.*last.*process/i) }
  end

  context 'when one of the jobs has already been forwarded' do
    let(:jobs) do
      orders.zip(job_sets, revised_sets, [Time.now, nil]).map do |order, set, revised_set, forwarded|
        create(:job, work_order: order, input_set_uuid: set.uuid, output_set_uuid: set.uuid,
             revised_output_set_uuid: revised_set&.uuid, started: Time.now, completed: Time.now,
             forwarded: forwarded)
      end
    end

    it { expect(service.execute).to fail_with_error(/.*already.*forwarded/) }
  end

  context 'when the plan is broken' do
    before { orders.first.update_attributes!(status: WorkOrder.BROKEN) }

    it { expect(service.execute).to fail_with_error(/.*plan.*broken/) }
  end

  context 'when a job does not have an output set' do
    let(:job_sets) { [nil, super()[1]] }

    it { expect(service.execute).to fail_with_error(/.*job.*output set/i) }
  end

  context 'when the revised job set is empty' do
    let(:revised_sets) { [nil, set_double(0)] }

    it { expect(service.execute).to fail_with_error(/.*no materials.*revised.*set/i) }
  end

  context 'when the unrevised job set is empty' do
    let(:job_sets) { [set_double(0), set_double(2)] }

    it { expect(service.execute).to fail_with_error(/.*no materials.*output.*set/i) }
  end

  context 'when the revised set has extraneous materials' do
    let(:revised_sets) { [nil, set_double(2)] }

    it { expect(service.execute).to fail_with_error(/.*extraneous materials.*revised.*set/i) }
  end

end
