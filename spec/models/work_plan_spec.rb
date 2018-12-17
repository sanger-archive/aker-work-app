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

  describe '#work_orders' do
    let!(:processes) { make_processes(3) }
    let(:plan) { create(:work_plan, product: product) }

    # Check that the order is definitely controlled by the order_index field
    it 'should be kept in order according to order_index' do
      create(:work_order, work_plan: plan, order_index: 0, process: processes.first)
      create(:work_order, work_plan: plan, order_index: 1, process: processes.second)
      create(:work_order, work_plan: plan, order_index: 2, process: processes.first)
      expect(plan.reload.work_orders.map(&:order_index)).to eq([0,1,2])
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
      end
      it { expect(plan.wizard_step).to eq('data_release_strategy') }
    end
    context 'when the data release strategy has also been selected' do
      let(:drs) { create(:data_release_strategy) }
      before do
        plan.update_attributes!(product: product, project_id: project.id, original_set_uuid: set.uuid, data_release_strategy_id: drs.id)
      end
      it { expect(plan.wizard_step).to eq('dispatch') }
    end
  end

  describe '#status' do
    let!(:processes) { make_processes(3) }
    let(:plan) { create(:work_plan, product: product, project_id: project.id, original_set_uuid: set.uuid) }
    let!(:orders) do
      processes.each_with_index do |pro, i|
        create(:work_order, work_plan: plan, order_index: i, process: pro)
      end
    end

    context 'when the plan is not yet started' do
      let(:orders) { [] }
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
      it { expect(plan.status).to eq('active') }
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
      end
      it { expect(plan.status).to eq('cancelled') }
    end
  end

  describe '#cancellable?' do
    let!(:processes) { make_processes(3) }
    let(:plan) { create(:work_plan, product: product, project_id: project.id, original_set_uuid: set.uuid) }
    let!(:orders) do
      processes.each_with_index do |pro, i|
        create(:work_order, work_plan: plan, order_index: i, process: pro)
      end
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

  describe '#user_permitted?' do
    let(:user) { OpenStruct.new(email: 'alaska@usa', groups: []) }
    let(:user_with_groups) { OpenStruct.new(email: 'alaska@usa', groups: ['pirates', owner.email]) }
    let(:owner) { OpenStruct.new(email: 'owner@here', groups: []) }
    let(:plan) { build(:work_plan, owner_email: owner.email) }
    context 'when the access is :read' do
      it 'always returns true' do
        expect(plan.user_permitted?(plan, user, :read)).to be_truthy
      end
    end
    context 'when the access is :create' do
      it 'always returns true' do
        expect(plan.user_permitted?(plan, user, :create)).to be_truthy
      end
    end

    context 'when the access is :write' do
      context 'when the user is the owner' do
        it { expect(plan.user_permitted?(plan, owner, :write)).to be_truthy }
      end
      context 'when the users groups include the owners email' do
        it { expect(plan.user_permitted?(plan, user_with_groups, :write)).to be_truthy }
      end

      context 'when the plan is in construction' do
        before do
          allow(plan).to receive(:in_construction?).and_return(true)
        end
        it { expect(plan.user_permitted?(plan, user, :write)).to be_falsey }
      end

      context 'when the plan is not in construction' do
        before do
          allow(plan).to receive(:in_construction?).and_return(false)
        end
        context 'when the user does not have spend permission on the plans project' do
          before do
            allow(Study).to receive(:current_user_has_spend_permission_on_project?).and_return(false)
          end
          it { expect(plan.user_permitted?(plan, user, :write)).to be_falsey }
        end
        context 'when the user does have spend permission on the plans project' do
          before do
            allow(Study).to receive(:current_user_has_spend_permission_on_project?).and_return(true)
          end
          it { expect(plan.user_permitted?(plan, user, :write)).to be_truthy }
        end
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

  describe '#modifiable_by' do
    let(:user) { OpenStruct.new(email: 'alaska@usa') }
    let(:project) { proj = double(:project, id: 12) }
    let(:plan1) { create(:work_plan, owner_email: user.email) }
    let(:plan2) { create(:work_plan, project_id: project.id) }
    let(:plan3) { create(:work_plan, owner_email: 'other@here') }

    before do
      allow(Study).to receive(:spendable_projects).with(user).and_return([project])
    end

    it 'should return plans belonging to the given user, or plans with a project the user has spend permissions on' do
      expect(WorkPlan.modifiable_by(user)).to eq([plan1, plan2])
    end
  end

  describe '#active_status' do
    let!(:processes) { make_processes(3) }
    let(:plan) { create(:work_plan, product: product, project_id: project.id, original_set_uuid: set.uuid) }
    let!(:orders) do
      wos = processes.each_with_index do |pro, i|
        create(:work_order, work_plan: plan, order_index: i, process: pro)
      end
      plan.reload
      wos
    end

    context 'when an order is in progress' do
      it 'should say the process is in progress' do
        plan.work_orders.first.update_attributes!(status: WorkOrder.CONCLUDED)
        order = plan.work_orders[1]
        order.update_attributes!(status: WorkOrder.ACTIVE)
        expect(plan.active_status).to eq("#{order.process.name} in progress")
      end
    end

    context 'when order concluded' do
      it 'should say that the process was concluded' do
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
