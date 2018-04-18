# frozen_string_literal: true

require 'rails_helper'
require 'support/work_orders_helper'
RSpec.describe WorkOrder, type: :model do
  include WorkOrdersHelper

  let(:catalogue) { create(:catalogue) }
  let(:product) { create(:product, name: 'Solylent Green', product_version: 3, catalogue: catalogue) }
  let(:process) do
    pro = create(:aker_process, name: 'Baking')
    create(:aker_product_process, product: product, aker_process: pro, stage: 0)
    pro
  end
  let(:process_options) do
    product.processes.map do |pro|
      pro.process_modules.map(&:id)
    end
  end
  let(:project) { make_node('Operation Wolf', 'S1001', 41, 40, false, true, SecureRandom.uuid) }
  let(:subproject) { make_node('Operation Thunderbolt', 'S1001-0', 42, project.id, true, false, nil) }

  let(:plan) { create(:work_plan, project_id: subproject.id, product: product, comment: 'hello', desired_date: '2020-01-01') }

  before do
    @barcode_index = 100
    bfc = double('BillingFacadeClient')
    stub_const("BillingFacadeClient", bfc)
    stub_const('BrokerHandle', class_double('BrokerHandle'))
    allow(bfc).to receive(:validate_process_module_name) do |name|
      !name.starts_with? 'x'
    end
  end

  describe '#finished_set' do
    context 'when the work order has a finished set uuid' do
      let(:finished_set) { make_set(6) }
      let(:wo) { build(:work_order, finished_set_uuid: finished_set.uuid) }
      it 'should return the finished set' do
        expect(wo.finished_set).to eq finished_set
      end
    end
    context 'when the work order has no finished set uuid' do
      let(:wo) { build(:work_order) }
      it 'should return nil' do
        expect(wo.finished_set).to be_nil
      end
    end
  end

  describe "#set" do
    let(:set) { make_set(6) }

    context "when work order has a set" do
      let(:order) { build(:work_order, set: set) }

      it "should return the set" do
        expect(order.set).to be set
      end
    end
    context "when work order has a set uuid" do
      let(:order) { build(:work_order, set_uuid: set.uuid) }

      it "should look up the set and return it" do
        expect(order.set).to eq set
      end
    end
    context "when work order has no set" do
      let(:order) { build(:work_order, set_uuid: nil, set: nil) }

      it "should return nil" do
        expect(order.set).to be_nil
      end
    end

    context "when set is assigned in the work order" do
      let(:order) { build(:work_order) }

      it "should update the set_uuid" do
        expect(order.set).to be_nil
        expect(order.set_uuid).to be_nil
        order.set = set
        expect(order.set).to be(set)
        expect(order.set_uuid).to eq(set.uuid)
      end
    end
    context "when set_uuid is assigned in the work order" do
      let(:order) { build(:work_order) }

      it "should update the set" do
        expect(order.set).to be_nil
        expect(order.set_uuid).to be_nil
        order.set_uuid = set.uuid
        expect(order.set).to eq(set)
        expect(order.set_uuid).to eq(set.uuid)
      end
    end
  end

  describe "#original_set" do
    let(:set) { make_set(6) }
    context "when work order has an original_set" do
      let(:order) { build(:work_order, original_set: set) }

      it "should return the set" do
        expect(order.original_set).to be(set)
      end
    end
    context "when work order has an original_set_uuid" do
      let(:order) { build(:work_order, original_set_uuid: set.uuid) }

      it "should look up the set and return it" do
        expect(order.original_set).to eq(set)
      end
    end
    context "when work order has no original set" do
      let(:order) { build(:work_order, original_set_uuid: nil, original_set: nil) }
      it "should return nil" do
        expect(order.original_set).to be_nil
      end
    end

    context "when the Set Client cannot find the original set" do
      let(:set_uuid) { SecureRandom.uuid }
      let(:order) { build(:work_order, original_set_uuid: @uuid) }

      before do
        allow(SetClient::Set).to receive(:find).with(set_uuid).and_raise(JsonApiClient::Errors::NotFound, "a message")
      end

      it "should return nil" do
        expect(order.original_set).to be_nil
      end
    end

    context "when original_set is assigned in the work order" do
      let(:order) { build(:work_order, original_set: nil, original_set_uuid: nil) }

      it "should update the original_set_uuid" do
        expect(order.original_set).to be_nil
        expect(order.original_set_uuid).to be_nil
        order.original_set = set
        expect(order.original_set).to be(set)
        expect(order.original_set_uuid).to eq(set.uuid)
      end
    end
    context "when original_set_uuid is assigned in the work order" do
      let(:order) { build(:work_order, original_set: nil, original_set_uuid: nil) }

      it "should update the original_set_uuid" do
        expect(order.original_set).to be_nil
        expect(order.original_set_uuid).to be_nil
        order.original_set_uuid = set.uuid
        expect(order.original_set).to eq(set)
        expect(order.original_set_uuid).to eq(set.uuid)
      end
    end
  end

  describe '#module_choices' do
    let(:order) { create(:work_order, process: process, work_plan: plan) }
    let(:modules) do
      (1...3).map { |i| create(:aker_process_module, name: "Module#{i}", aker_process_id: process.id) }
    end

    before do
      modules.each_with_index { |m,i| WorkOrderModuleChoice.create(work_order: order, process_module: m, position: i)}
    end

    it 'returns the module names' do
      expect(order.module_choices).to eq(["Module1", "Module2"])
    end
  end

  describe '#validate_module_names' do
    let(:order) { create(:work_order, process: process, work_plan: plan) }

    context 'when modules are all valid' do
      it 'should not raise an exception' do
        expect { order.validate_module_names(['alpha', 'beta']) }.not_to raise_exception
      end
    end
    context 'when any modules are invalid' do
      it 'should raise an exception' do
        expect { order.validate_module_names(['alpha', 'xbeta', 'xgamma', 'delta']) }
          .to raise_exception('Process module could not be validated: ["xbeta", "xgamma"]')
      end
    end
  end


  describe '#finalise_set' do
    let(:unlocked_set) { make_set }
    let(:another_unlocked_set) { make_set }
    let(:locked_set) do
      x = make_set
      allow(x).to receive(:locked).and_return(true)
      x
    end
    let(:original_set_uuid) { unlocked_set.uuid }
    let(:input_set_uuid) { nil }

    let(:order) { create(:work_order, id: 42, work_plan: plan, set_uuid: input_set_uuid, original_set_uuid: original_set_uuid) }

    context 'when the order already has a locked input set' do
      let(:input_set_uuid) { locked_set.uuid }
      it 'should do nothing' do
        expect(order.finalise_set).to be_falsey
      end
    end
    context 'when the order has an unlocked input set' do
      let(:input_set_uuid) { another_unlocked_set.uuid }
      it 'should lock the input set and return true' do
        expect(another_unlocked_set).to receive(:update_attributes).with(locked: true) do
          allow(another_unlocked_set).to receive(:locked).and_return true
        end
        expect(order.finalise_set).to be_truthy
      end
    end
    context 'when the input set fails to be locked' do
      let(:input_set_uuid) { another_unlocked_set.uuid }
      it 'should raise an exception' do
        allow(another_unlocked_set).to receive(:name).and_return('myset')
        expect(another_unlocked_set).to receive(:update_attributes).with(locked: true)
        expect { order.finalise_set }.to raise_exception "Failed to lock set #{another_unlocked_set.name}"
      end
    end
    context 'when the order has a locked original set' do
      let(:original_set_uuid) { locked_set.uuid }
      it 'should set the input set to the original set' do
        expect(order.finalise_set).to be_falsey
        expect(order.set_uuid).to eq(original_set_uuid)
      end
    end
    context 'when the order has an unlocked original set' do
      it 'should create a locked clone of the original set' do
        expect(unlocked_set).to receive(:create_locked_clone).and_return(locked_set)
        expect(order.finalise_set).to be_truthy
        expect(order.set_uuid).to eq(locked_set.uuid)
      end
    end
    context 'when the order has no original set' do
      let(:original_set_uuid) { nil }
      it 'should raise an exception' do
        expect { order.finalise_set }.to raise_exception "No set selected for work order"
      end
    end
  end

  describe '#generate_concluded_event' do
    context 'if work order does not have status completed or cancelled' do
      it 'generates an event using the BrokerHandle' do
        wo = build(:work_order)
        expect(BrokerHandle).not_to receive(:publish).with(an_instance_of(WorkOrderEventMessage))
        expect(Rails.logger).to receive(:error).with('Concluded event cannot be generated from a work order where all the jobs are not either cancelled or completed.')
        wo.generate_concluded_event
      end
    end

    context 'if work order does have status completed or cancelled' do
      it 'generates an event using the BrokerHandle' do
        wo = build(:work_order, status: 'concluded')
        allow(BillingFacadeClient).to receive(:send_event).with(wo, 'concluded')
        expect(BrokerHandle).to receive(:publish).with(an_instance_of(WorkOrderEventMessage))
        wo.generate_concluded_event
      end
    end
  end

  describe '#generate_submitted_event' do
    context 'if work order does not have status active' do
      it 'generates an event using the BrokerHandle' do
        wo = build(:work_order)
        allow(BillingFacadeClient).to receive(:send_event).with(wo, 'submitted')
        expect(BrokerHandle).not_to receive(:publish).with(an_instance_of(WorkOrderEventMessage))
        expect(Rails.logger).to receive(:error).with('Submitted event cannot be generated from a work order that is not active.')
        wo.generate_submitted_event
      end
    end

    context 'if work order does have status active' do
      it 'generates an event using the BrokerHandle' do
        wo = build(:work_order, status: 'active')
        allow(BillingFacadeClient).to receive(:send_event).with(wo, 'submitted')
        expect(BrokerHandle).to receive(:publish).with(an_instance_of(WorkOrderEventMessage))
        wo.generate_submitted_event
      end
    end
  end

  describe "#total_tat" do
    it "calculates the total TAT" do
      process = build(:process, TAT: 4)
      order = build(:work_order, process: process)
      expect(order.total_tat).to eq(4)
    end
  end

  describe "#owner_email" do
    it "returns the work plans owner email" do
      process = build(:process, TAT: 4)
      plan = create(:work_plan)
      order = build(:work_order, process: process, work_plan: plan)
      expect(order.owner_email).to eq(plan.owner_email)
    end
  end

  describe '#can_be_dispatched?' do
    context 'when the work order is queued' do
      let!(:processes) { make_processes(3) }
      let(:plan) { create(:work_plan, product: product) }

      context 'when the last order in the plan, not closed, is the work order' do
        it 'should return true' do
          plan.create_orders(process_options, nil)
          plan.work_orders[0].update_attributes(status: WorkOrder.CONCLUDED)
          plan.work_orders[1].update_attributes(status: WorkOrder.CONCLUDED)
          plan.work_orders.reload

          expect(plan.work_orders[0].can_be_dispatched?).to eq(false)
          expect(plan.work_orders[1].can_be_dispatched?).to eq(false)
          expect(plan.work_orders[2].can_be_dispatched?).to eq(true)
        end
      end
      context 'when the last order in the plan, not closed, is not the work order' do
        it 'should return false' do
          plan.create_orders(process_options, nil)
          plan.work_orders[0].update_attributes(status: WorkOrder.QUEUED)
          plan.work_orders.reload

          expect(plan.work_orders[0].can_be_dispatched?).to eq(true)
          expect(plan.work_orders[1].can_be_dispatched?).to eq(false)
        end
      end
    end
    context 'when the work order not queued' do
      it 'should return false' do
        process = build(:process, TAT: 4)
        plan = create(:work_plan)
        order = build(:work_order, process: process, work_plan: plan, status: 'active')
        expect(order.can_be_dispatched?).to eq(false)
      end
    end
    context 'when the work plan is cancelled' do
      it 'should return false' do
        process = build(:process, TAT: 4)
        plan = create(:work_plan, cancelled: Time.now)
        order = build(:work_order, process: process, work_plan: plan, status: 'active')
        expect(order.can_be_dispatched?).to eq(false)
      end
    end
  end

  describe '#selected_path' do
    let!(:plan) { create (:work_plan) }
    let!(:order) { build(:work_order, process: process, work_plan: plan)}
    let(:modules) do
      (1..2).map { |i| create(:aker_process_module, name: "Module#{i}", aker_process_id: process.id) }
    end
    context 'when there are work order module choices for a work order' do
      it 'returns a list of module choices' do
        modules.each_with_index { |m,i| WorkOrderModuleChoice.create(work_order: order, process_module: m, position: i)}
        expect(order.selected_path).to eq([{name: modules[0].name, id: modules[0].id},{name: modules[1].name, id: modules[1].id}])
      end
    end
    context 'when there are no work order module choices for a work order' do
      it 'returns a empty list' do
        expect(order.selected_path).to eq([])
      end
    end
  end

  describe '#estimated_completion_date' do
    let!(:plan) { create (:work_plan) }
    let!(:process) { build(:process, TAT: 4) }

    context 'when the dispatch date doesnt exist' do
      let!(:order) { build(:work_order, process: process, work_plan: plan)}
      it 'should return nil' do
        expect(order.estimated_completion_date).to be nil
      end
    end
    context 'when the process doesnt exist' do
      let!(:process) { nil }
      let!(:order) { build(:work_order, work_plan: plan, dispatch_date: Date.today, process: nil )}
      it 'should return nil' do
        expect(order.estimated_completion_date).to be nil
      end
    end
    context 'when both the dispatch date and process doesnt exist' do
      let!(:order) { build(:work_order, work_plan: plan )}
      it 'should return nil' do
        expect(order.estimated_completion_date).to be nil
      end
    end
    context 'when both the dispatch date and process exist' do
      let!(:order) { build(:work_order, work_plan: plan, process: process, dispatch_date: Date.today )}
      it 'should the dispatch date + the process TAT' do
        expect(order.estimated_completion_date).to eq(order.dispatch_date+process.TAT)
      end
    end
  end

  describe '#create_jobs' do
    let(:order) { create(:work_order, process: process, work_plan: plan, set_uuid: @set.id) }
    let(:modules) do
      (1...3).map { |i| create(:aker_process_module, name: "Module#{i}", aker_process_id: process.id) }
    end

    before do
      @num_of_containers = 3
      make_set_with_materials

      grouped_materials = {}
      @materials.each_with_index do |material, pos|
        grouped_materials[(pos % @num_of_containers)] = [] unless grouped_materials[(pos % @num_of_containers)]
        grouped_materials[(pos % @num_of_containers)].push(material)
      end
      @containers = grouped_materials.values.map {|materials| make_container(materials) }
      modules.each_with_index { |m,i| WorkOrderModuleChoice.create(work_order: order, process_module: m, position: i)}
    end

    context 'when some of the materials are unavailable' do
      before do
        @materials[0].attributes['available'] = false
      end

      it "should raise an exception" do
        expect { order.create_jobs }.to raise_error(/materials.*available/)
      end
    end

    context 'when module name is not valid' do
      before do
        m = create(:aker_process_module, name: "xModule", aker_process_id: process.id)
        WorkOrderModuleChoice.create(work_order: order, process_module: m, position: 2)
      end
      it 'should raise an exception' do
        expect { order.create_jobs }.to raise_exception('Process module could not be validated: ["xModule"]')
      end
    end

    context 'when using several containers' do
      before do
        allow(MatconClient::Container).to receive(:where).with("slots.material": {
          "$in": @materials.map(&:id)
        }).and_return(make_result_set(@containers))
      end
      it 'creates as many jobs as containers' do
        order.create_jobs
        expect(order.jobs.length).to eq(@num_of_containers)
      end
    end

  end


  describe '#next_order' do
    let(:plan) { create(:work_plan) }
    let(:work_order) { create(:work_order, order_index: 0, work_plan: plan) }
    context 'when there is a next order' do
      let!(:next_order) { create(:work_order, order_index: 1, work_plan: plan) }
      it 'should return the next order' do
        expect(work_order.next_order).to eq(next_order)
      end
    end

    context 'when there is no next order' do
      it 'should return nil' do
        expect(work_order.next_order).to be_nil
      end
    end
  end

  describe '#create_editable_set' do
    let(:set) { make_set(1) }

    context 'when the work order already has an input set' do
      let(:work_order) { create(:work_order, original_set: set, set: set) }
      it { expect { work_order.create_editable_set }.to raise_exception "Work order already has input set" }
    end

    context 'when the work order has no original set' do
      let(:work_order) { create(:work_order, original_set: nil, set: nil) }
      it { expect { work_order.create_editable_set }.to raise_exception "Work order has no original set" }
    end

    context 'when the new set is created' do
      let(:new_set) { make_set(1) }
      before do
        allow(set).to receive(:create_unlocked_clone).and_return(new_set)
      end
      let(:work_order) { create(:work_order, original_set: set, set: nil) }
      it 'should return the new set' do
        expect(work_order.create_editable_set).to eq(new_set)
        expect(set).to have_received(:create_unlocked_clone).with(work_order.name)
      end
    end
  end
end
