# frozen_string_literal: true

require 'rails_helper'
require 'support/work_orders_helper'
RSpec.describe WorkOrder, type: :model do
  include WorkOrdersHelper

  let(:catalogue) { create(:catalogue) }
  let(:product) { create(:product, name: 'Soylent Green', product_version: 3, catalogue: catalogue) }
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
  let(:project) { make_node('Operation Wolf', 'S1001', 41, 40, false, true) }
  let(:subproject) { make_node('Operation Thunderbolt', 'S1001-0', 42, project.id, true, false) }

  let(:plan) { create(:work_plan, project_id: subproject.id, product: product, comment: 'hello') }

  before do
    @barcode_index = 100
    bfc = double('BillingFacadeClient')
    stub_const("BillingFacadeClient", bfc)
    stub_const('BrokerHandle', class_double('BrokerHandle'))
    allow(BrokerHandle).to receive(:publish)
    allow(bfc).to receive(:validate_process_module_name) do |name|
      !name.starts_with? 'x'
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

  describe '#generate_dispatched_event' do
    context 'if work order does not have status active' do
      it 'generates an event using the BrokerHandle' do
        wo = build(:work_order)
        allow(BillingFacadeClient).to receive(:send_event).with(wo, 'dispatched')
        expect(BrokerHandle).not_to receive(:publish).with(an_instance_of(WorkOrderEventMessage))
        expect(Rails.logger).to receive(:error).with('dispatched event cannot be generated from a work order that is not active.')
        wo.generate_dispatched_event
      end
    end

    context 'if work order does have status active' do
      it 'generates an event using the BrokerHandle' do
        wo = build(:work_order, status: 'active')
        allow(BillingFacadeClient).to receive(:send_event).with(wo, 'dispatched')
        expect(BrokerHandle).to receive(:publish).with(an_instance_of(WorkOrderEventMessage))
        wo.generate_dispatched_event
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
      let(:modules_selected_values) { processes.map{ [nil] }}
      let(:plan) { create(:work_plan, product: product) }

      context 'when the last order in the plan, not closed, is the work order' do
        it 'should return true' do
          plan.create_orders(process_options, nil, modules_selected_values)
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
          plan.create_orders(process_options, nil, modules_selected_values)
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
        expect(order.selected_path).to eq([{name: modules[0].name, id: modules[0].id, selected_value: nil},{name: modules[1].name, id: modules[1].id, selected_value: nil}])
      end
      it 'includes the selected values for the choices' do
        modules.each_with_index { |m,i| WorkOrderModuleChoice.create(work_order: order, process_module: m, position: i, selected_value: i)}
        expect(order.selected_path).to eq([
          {name: modules[0].name, id: modules[0].id, selected_value: 0},
          {name: modules[1].name, id: modules[1].id, selected_value: 1}
        ])
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
      let!(:order) { build(:work_order, work_plan: plan, dispatch_date: Time.now, process: nil )}
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
      let!(:order) { build(:work_order, work_plan: plan, process: process, dispatch_date: Time.now )}
      it 'should the dispatch date + the process TAT' do
        expect(order.estimated_completion_date).to eq(order.dispatch_date+process.TAT)
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

end
