require 'rails_helper'
require 'ostruct'

RSpec.describe WorkPlan, type: :model do
  let(:catalogue) { create(:catalogue) }
  let(:product) { create(:product, catalogue: catalogue) }
  let(:project) { make_project(12) }
  let(:process_options) do
    product.processes.map do |pro|
      pro.process_modules.map(&:id)
    end
  end

  let(:modules_selected_values) do
    process_options.map {|list| list.map{ nil }}
  end

  let(:set) do
    s = make_set
    allow(s).to receive(:create_locked_clone).and_return(locked_set)
    s
  end

  let(:locked_set) { make_set }

  def make_set(size=3)
    uuid = SecureRandom.uuid
    s = double(:set, uuid: uuid, id: uuid, meta: { 'size' => size })
    allow(SetClient::Set).to receive(:find).with(s.uuid).and_return([s])
    return s
  end

  def make_processes(n)
    pros = (0...n).map { |i| create(:aker_process, name: "process #{i}") }
    pros.each_with_index { |pro, i| create(:aker_product_process, product: product, aker_process: pro, stage: i) }
    i = 0
    pros.each do |pro|
      (0...3).each do
        Aker::ProcessModule.create!(name: "module-#{i}", aker_process_id: pro.id)
        i += 1
      end
    end
    pros
  end

  def make_project(id)
    proj = double(:project, id: id)
    allow(StudyClient::Node).to receive(:find).with(id).and_return([proj])
    proj
  end

  describe '#uuid' do
    context 'when a new plan is made' do
      it 'is given a uuid' do
        plan = WorkPlan.new(owner_email: 'dave')
        expect(plan.uuid).not_to be_nil
      end
    end

    context 'when a plan is loaded' do
      it 'retains its uuid' do
        plan = WorkPlan.new(owner_email: 'dave')
        first_uuid = plan.uuid
        plan.save!
        plan = WorkPlan.find(plan.id)
        expect(plan.uuid).to eq(first_uuid)
      end
    end
  end

  describe '#data_release_strategy' do
    context 'when the plan has a data_release_strategy' do
      let(:drs) { create(:data_release_strategy) }
      let(:plan) do
        pl = create(:work_plan, data_release_strategy_id: drs.id)
        allow(pl).to receive(:data_release_strategy).and_return drs
        pl
      end
      it 'has a data release strategy' do
        expect(plan.data_release_strategy).to eq(drs)
      end
    end
    context 'when the plan has no data_release_strategy' do
      let(:plan) { build(:work_plan) }
      it { expect(plan.data_release_strategy).to eq(nil) }
    end
  end

  describe '#owner_email' do
    it 'should be sanitised' do
      expect(create(:work_plan, owner_email: '    ALPHA@BETA   ').owner_email).to eq('alpha@beta')
    end
  end

  describe '#create_orders' do

    context 'when no product is selected' do
      let(:plan) { create(:work_plan, original_set_uuid: set.uuid) }

      it { expect { plan.create_orders(process_options, nil, modules_selected_values) }.to raise_error("No product is selected") }
    end

    context 'when work orders already exist' do
      let(:existing_orders) { ['existing orders'] }
      let(:plan) do
        pl = create(:work_plan, product: product, original_set_uuid: set.uuid)
        allow(pl).to receive(:work_orders).and_return existing_orders
        pl
      end

      it 'should return the existing orders' do
        expect(plan.create_orders(process_options, nil, modules_selected_values)).to eq(existing_orders)
      end
    end

    context 'when work orders need to be created' do
      let!(:processes) { make_processes(3) }
      let(:plan) { create(:work_plan, product: product, original_set_uuid: set.uuid) }
      let(:orders) { plan.create_orders(process_options, nil, modules_selected_values) }

      it 'should create an order for each process' do
        expect(orders.length).to eq(processes.length)
        orders.zip(processes).each do |order, pro|
          expect(order.id).not_to be_nil
          expect(order.process).to eq(pro)
          expect(order.work_plan).to eq(plan)
        end
      end

      it 'should set the order_index correctly on orders' do
        orders.each_with_index do |order, i|
          expect(order.order_index).to eq(i)
        end
      end

      it 'should have orders in state queued' do
        orders.each { |o| expect(o.status).to eq(WorkOrder.QUEUED) }
      end

      it 'should be possible to retrieve the orders from the plan later' do
        expect(WorkPlan.find(plan.id).work_orders).to eq(orders)
      end

      it 'should set the sets correctly' do
        expect(orders.first.original_set_uuid).to eq(plan.original_set_uuid)
        expect(orders.first.set_uuid).to be_nil
        orders[1..-1].each do |o|
          expect(o.original_set_uuid).to be_nil
          expect(o.set_uuid).to be_nil
        end
      end
    end

    context 'when a locked set uuid is supplied' do
      let(:locked_set_uuid) { SecureRandom.uuid }
      let!(:processes) { make_processes(3) }
      let(:plan) { create(:work_plan, product: product, original_set_uuid: set.uuid) }
      let(:orders) { plan.create_orders(process_options, locked_set_uuid, modules_selected_values) }

      it 'should set the sets correctly' do
        expect(orders.first.original_set_uuid).to eq(plan.original_set_uuid)
        expect(orders.first.set_uuid).to eq(locked_set_uuid)
        orders[1..-1].each do |o|
          expect(o.original_set_uuid).to be_nil
          expect(o.set_uuid).to be_nil
        end
      end

    end

  end

  describe '#work_orders' do
    let!(:processes) { make_processes(3) }
    let(:plan) { create(:work_plan, product: product) }

    # Check that the order is definitely controlled by the order_index field
    it 'should be kept in order according to order_index' do
      expect(plan.create_orders(process_options, nil, modules_selected_values).map(&:order_index)).to eq([0,1,2])
      plan.work_orders[1].update_attributes(order_index: 5)
      expect(plan.work_orders.reload.map(&:order_index)).to eq([0,2,5])
      plan.work_orders[0].update_attributes(order_index: 4)
      expect(plan.work_orders.reload.map(&:order_index)).to eq([2,4,5])
    end
  end

  describe '#wizard_step' do
    let!(:processes) { make_processes(3) }
    let(:plan) { create(:work_plan) }

    context 'when the original set has not been selected' do
      it { expect(plan.wizard_step).to eq('set') }
    end

    context 'when the original set has been selected and the project has not been selected' do
      before do
        plan.update_attributes(original_set_uuid: set.uuid)
      end
      it { expect(plan.wizard_step).to eq('project') }
    end

    context 'when the project has also been selected and the product has not been selected' do
      before do
        plan.update_attributes!(project_id: project.id, original_set_uuid: set.uuid)
      end
      it { expect(plan.wizard_step).to eq('product') }
    end

    context 'when the product has also been selected' do
      before do
        plan.update_attributes!(product: product, project_id: project.id, original_set_uuid: set.uuid)
        plan.create_orders(process_options, nil, modules_selected_values).first.update_attributes!(set_uuid: set.uuid)
      end
      it { expect(plan.wizard_step).to eq('data_release_strategy') }
    end
    context 'when the data release strategy has also been selected' do
      let(:drs) { create(:data_release_strategy) }
      before do
        plan.update_attributes!(product: product, project_id: project.id, original_set_uuid: set.uuid, data_release_strategy_id: drs.id)
        plan.create_orders(process_options, nil, modules_selected_values).first.update_attributes!(set_uuid: set.uuid)
      end
      it { expect(plan.wizard_step).to eq('dispatch') }
    end
  end

  describe '#status' do
    let!(:processes) { make_processes(3) }
    let(:plan) do
      pl = create(:work_plan, product: product, project_id: project.id, original_set_uuid: set.uuid)
      pl.create_orders(process_options, nil, modules_selected_values).first.update_attributes!(set_uuid: set.uuid)
      pl
    end

    context 'when the plan is not yet started' do
      it { expect(plan.status).to eq('construction') }
    end

    context 'when any of the orders is broken' do
      before do
        plan.work_orders.first.broken!
        plan.reload
      end
      it { expect(plan.status).to eq('broken') }
    end

    context 'when all the orders are closed' do
      before do
        plan.work_orders.each_with_index { |order,i| order.update_attributes(status: WorkOrder.CONCLUDED) }
        plan.reload
      end
      it { expect(plan.status).to eq('closed') }
    end

    context 'when an order is in progress' do
      before do
        plan.work_orders.first.update_attributes(status: WorkOrder.ACTIVE)
        plan.reload
      end
      it { expect(plan.status).to eq('active') }
    end

    context 'when the plan is cancelled' do
      before do
        plan.update_attributes(cancelled: Time.now)
        plan.reload
      end
      it { expect(plan.status).to eq('cancelled') }
    end
  end

  describe '#cancellable?' do
    let!(:processes) { make_processes(3) }
    let(:plan) do
      pl = create(:work_plan, product: product, project_id: project.id, original_set_uuid: set.uuid)
      pl.create_orders(process_options, nil, modules_selected_values)
      pl
    end

    context 'when a work plan is cancellable' do
      it { expect(plan.cancellable?).to be true }
    end

    context 'when a work plan is not cancellable' do
      before do
        plan.work_orders.first.broken!
        plan.reload
      end
      it { expect(plan.cancellable?).to be false }
    end
  end

  describe '#permitted?' do
    let(:owner) { 'user@here' }
    let(:plan) { build(:work_plan, owner_email: owner) }
    context 'when the access is :read' do
      it 'always returns true' do
        expect(plan.permitted?('anything', :read)).to be_truthy
        expect(plan.permitted?(['anything'], :read)).to be_truthy
      end
    end
    context 'when the access is :create' do
      it 'always returns true' do
        expect(plan.permitted?('anything', :create)).to be_truthy
        expect(plan.permitted?(['anything'], :create)).to be_truthy
      end
    end
    context 'when the access is :write' do
      context 'when the parameter is the owner email' do
        it { expect(plan.permitted?(owner, :write)).to be_truthy }
      end
      context 'when the parameter is another string' do
        it { expect(plan.permitted?('somethingelse', :write)).to be_falsey }
      end
      context 'when the parameter is an array including the owner email' do
        it { expect(plan.permitted?(['alpha', owner, 'beta'], :write)).to be_truthy }
      end
      context 'when the parameter is an array not including the owner email' do
        it { expect(plan.permitted?(['alpha', 'beta'], :write)).to be_falsey }
      end
    end
  end

  describe '#for_user' do
    let(:user1) { OpenStruct.new(email: 'alaska@usa') }
    let(:user2) { OpenStruct.new(email: 'alabama@usa') }
    let(:user3) { OpenStruct.new(email: 'arizona@usa') }
    let!(:plans) do
      [ user1, user1, user2 ].map { |user| create(:work_plan, owner_email: user.email) }
    end

    it 'should return plans belonging to the given user' do
      expect(WorkPlan.for_user(user1)).to eq(plans[0..1])
      expect(WorkPlan.for_user(user2)).to eq(plans[2..2])
      expect(WorkPlan.for_user(user3)).to eq([])
    end
  end

  describe '#active_status' do
    let(:plan) do
      pl = create(:work_plan, product: product, project_id: project.id, original_set_uuid: set.id)
      pl.create_orders(process_options, nil, modules_selected_values)
      pl.work_orders.reload
      pl
    end

    before do
      make_processes(3)
    end

    context 'when an order is in progress' do
      it 'should say the process is in progress' do
        plan.work_orders.first.update_attributes!(status: WorkOrder.CONCLUDED)
        order = plan.work_orders[1]
        order.update_attributes!(status: WorkOrder.ACTIVE)
        expect(plan.active_status).to eq("#{order.process.name} in progress")
      end
    end

    context 'when order cancelled' do
      it 'should say that the process was cancelled' do
        plan.work_orders.first.update_attributes!(status: WorkOrder.CONCLUDED)
        order = plan.work_orders[1]
        order.update_attributes!(status: WorkOrder.CONCLUDED)
        expect(plan.active_status).to eq("#{order.process.name} concluded")
      end
    end

    context 'when order completed' do
      it 'should say that the process was completed' do
        plan.work_orders.first.update_attributes!(status: WorkOrder.CONCLUDED)
        order = plan.work_orders[1]
        order.update_attributes!(status: WorkOrder.CONCLUDED)
        expect(plan.active_status).to eq("#{order.process.name} concluded")
      end
    end
  end

  describe '#name' do
    it 'should say work plan and the id' do
      plan = create(:work_plan)
      expect(plan.name).to eq("Work plan #{plan.id}")
    end
  end

  describe '#cancelled' do
    context 'when a new work plan is created' do
      it 'should have cancelled set to nil' do
        plan = create(:work_plan)
        expect(plan.cancelled).to be_nil
        expect(plan).not_to be_cancelled
      end
    end

    context 'when a work plan is cancelled' do
      it 'should have cancelled set to the time of cancelling' do
        plan = create(:work_plan)
        cancelled_time = Time.now
        plan.update_attributes(cancelled: cancelled_time)
        plan = WorkPlan.find(plan.id)
        expect(plan.cancelled).not_to be_nil
        # timestamp loses some precision when it is stored in the database
        expect(plan.cancelled).to be_within(1.second).of cancelled_time
        expect(plan).to be_cancelled
        expect(plan.status).to eq('cancelled')
      end
    end
  end

  describe '#is_product_from_sequencescape?' do
    context 'when the plans product catalogue url is not sequencescape' do
      it 'should return false' do
        catalogue.update_attributes!(lims_id: 'not_SQSC')
        plan = create(:work_plan, product: product)
        expect(plan.is_product_from_sequencescape?).to eq false
      end
    end
    context 'when the plans product catalogue url is sequencescape' do
      it 'should return true' do
        catalogue.update_attributes!(lims_id: 'SQSC')
        plan = create(:work_plan, product: product)
        expect(plan.is_product_from_sequencescape?).to eq true
      end
    end
  end

  describe 'priority' do
    context 'default' do
      it 'should be standard' do
        plan = create(:work_plan)
        expect(plan.priority).to eq 'standard'
      end
    end
    context 'when it is set to high' do
      it 'should be high' do
        plan = create(:work_plan, priority: 'high')
        expect(plan.priority).to eq 'high'
      end
    end
  end
end
