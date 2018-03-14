require 'rails_helper'
require 'ostruct'

RSpec.describe WorkPlan, type: :model do
  let(:catalogue) { create(:catalogue) }
  let(:product) { create(:product, catalogue: catalogue) }
  let(:project) do
    proj = double(:project, id: 12)
    allow(StudyClient::Node).to receive(:find).with(proj.id).and_return([proj])
    proj
  end
  let(:process_options) do
    product.processes.map do |pro|
      pro.process_modules.map(&:id)
    end
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

  describe '#project' do
    let(:other_project) { double(:project, id: 13) }

    context 'when the plan has no project id' do
      let(:plan) { build(:work_plan) }
      it { expect(plan.project).to be_nil }
    end

    context 'when the plan has a project id' do
      let(:plan) { build(:work_plan, project_id: project.id) }
      it { expect(plan.project).to eq(project) }
    end

    context 'when the plan has a @project with a different project_id' do
      let(:plan) do
        pl = build(:work_plan, project_id: project.id)
        pl.instance_variable_set('@project', other_project)
        pl
      end
      it 'should reload the correct project' do
        expect(plan.project).to eq(project)
      end
    end

    context 'when the plan has a @project with the correct project id' do
      let(:plan) do
        pl = build(:work_plan, project_id: other_project.id)
        pl.instance_variable_set('@project', other_project)
        pl
      end
      it 'should return the project' do
        expect(plan.project).to eq(other_project)
      end
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

      it { expect { plan.create_orders(process_options, nil) }.to raise_error("No product is selected") }
    end

    context 'when work orders already exist' do
      let(:existing_orders) { ['existing orders'] }
      let(:plan) do
        pl = create(:work_plan, product: product, original_set_uuid: set.uuid)
        allow(pl).to receive(:work_orders).and_return existing_orders
        pl
      end

      it 'should return the existing orders' do
        expect(plan.create_orders(process_options, nil)).to eq(existing_orders)
      end
    end

    context 'when work orders need to be created' do
      let!(:processes) { make_processes(3) }
      let(:plan) { create(:work_plan, product: product, original_set_uuid: set.uuid) }
      let(:orders) { plan.create_orders(process_options, nil) }

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
        expect(orders.first.set_uuid).to eq(locked_set.uuid)
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
      let(:orders) { plan.create_orders(process_options, locked_set_uuid) }

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
      expect(plan.create_orders(process_options, nil).map(&:order_index)).to eq([0,1,2])
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
        plan.create_orders(process_options, nil).first.update_attributes!(set_uuid: set.uuid)
      end
      it { expect(plan.wizard_step).to eq('dispatch') }
    end
  end

  describe '#status' do
    let!(:processes) { make_processes(3) }
    let(:plan) do
      pl = create(:work_plan, product: product, project_id: project.id, original_set_uuid: set.uuid)
      pl.create_orders(process_options, nil).first.update_attributes!(set_uuid: set.uuid)
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
        plan.work_orders.each_with_index { |order,i| order.update_attributes(status: i==0 ? WorkOrder.COMPLETED : WorkOrder.CANCELLED) }
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
  end

  describe '#original_set' do
    context 'when the plan has no set uuid' do
      let(:plan) { build(:work_plan, original_set_uuid: nil) }

      it { expect(plan.original_set).to be_nil }
    end

    context 'when the plan has a set uuid' do
      let(:plan) { build(:work_plan, original_set_uuid: set.uuid) }

      it 'should return the set' do
        expect(plan.original_set).to eq(set)
      end
    end

    context 'when the plan has a new set uuid' do
      let(:plan) { build(:work_plan, original_set_uuid: set.uuid) }
      let(:another_set) { make_set }

      it 'should reload when changed' do
        expect(plan.original_set).to eq(set)
        plan.original_set_uuid = another_set.uuid
        expect(plan.original_set).to eq(another_set)
      end
    end
  end

  describe '#num_original_samples' do
    context 'when the plan has no set' do
      let(:plan) { build(:work_plan) }
      it { expect(plan.num_original_samples).to be_nil }
    end

    context 'when the plan has a set' do
      let(:plan) { build(:work_plan, original_set_uuid: set.id) }
      it 'should return the size of the set' do
        expect(plan.num_original_samples).to eq(set.meta['size'])
      end
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
      pl.create_orders(process_options, nil)
      pl.work_orders.reload
      pl
    end

    before do
      make_processes(3)
    end

    context 'when an order is in progress' do
      it 'should say the process is in progress' do
        plan.work_orders.first.update_attributes!(status: WorkOrder.COMPLETED)
        order = plan.work_orders[1]
        order.update_attributes!(status: WorkOrder.ACTIVE)
        expect(plan.active_status).to eq("#{order.process.name} in progress")
      end
    end

    context 'when order cancelled' do
      it 'should say that the process was cancelled' do
        plan.work_orders.first.update_attributes!(status: WorkOrder.COMPLETED)
        order = plan.work_orders[1]
        order.update_attributes!(status: WorkOrder.CANCELLED)
        expect(plan.active_status).to eq("#{order.process.name} cancelled")
      end
    end

    context 'when order completed' do
      it 'should say that the process was completed' do
        plan.work_orders.first.update_attributes!(status: WorkOrder.CANCELLED)
        order = plan.work_orders[1]
        order.update_attributes!(status: WorkOrder.COMPLETED)
        expect(plan.active_status).to eq("#{order.process.name} completed")
      end
    end
  end

  describe '#name' do
    it 'should say work plan and the id' do
      plan = create(:work_plan)
      expect(plan.name).to eq("Work plan #{plan.id}")
    end
  end

end
