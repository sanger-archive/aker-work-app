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
    context 'when work order does not have status completed or cancelled' do
      it 'does not generate an event using the BrokerHandle' do
        wo = build(:work_order)
        expect(BrokerHandle).not_to receive(:publish)
        expect(Rails.logger).to receive(:error).with('Concluded event cannot be generated from a work order where all the jobs are not either cancelled or completed.')
        wo.generate_concluded_event
      end
    end

    context 'when work order does have status completed or cancelled' do
      it 'generates an event using the BrokerHandle' do
        wo = build(:work_order, status: 'concluded')
        allow(BillingFacadeClient).to receive(:send_event).with(wo, 'concluded')
        expect(BrokerHandle).to receive(:publish).with(an_instance_of(WorkOrderEventMessage))
        wo.generate_concluded_event
      end
    end
  end

  describe '#generate_dispatched_event' do
    before do
      allow(BillingFacadeClient).to receive(:send_event)
    end
    context 'when work order does not have status active' do
      it 'does not generate an event using the BrokerHandle' do
        wo = build(:work_order)
        expect(BrokerHandle).not_to receive(:publish)
        expect(Rails.logger).to receive(:error).with('Dispatched event cannot be generated from a work order that is not active.')
        wo.generate_dispatched_event([])
      end
    end

    context 'when work order does have status active' do
      it 'generates an event using the BrokerHandle' do
        wo = build(:work_order, status: 'active')
        expect(BrokerHandle).to receive(:publish).with(an_instance_of(WorkOrderEventMessage))
        wo.generate_dispatched_event([])
      end
    end

    context 'when forwarded jobs are passed to the method' do
      it 'generates an event with the forwarded jobs' do
        wo = build(:work_order, status: 'active')
        fjobs = (0...2).map { build(:job) }
        expect(BrokerHandle).to receive(:publish) do |event|
          expect(instance_variable_get(event), '@forwarded_jobs').to eq(fjobs)
        end
        wo.generate_dispatched_event(fjobs)
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
    let!(:processes) { make_processes(3) }
    let(:modules_selected_values) { processes.map{ [nil] } }
    let(:plan_cancelled) { nil }
    let(:plan) { create(:work_plan, product: product, cancelled: plan_cancelled) }
    let(:order_status) { WorkOrder.QUEUED }
    let(:order) { create(:work_order, work_plan: plan, process: processes.first, status: order_status) }

    context 'when the order is queued' do
      it { expect(order).to be_can_be_dispatched }
    end

    context 'when the order is not queued' do
      let(:order_status) { WorkOrder.CONCLUDED }

      it { expect(order).not_to be_can_be_dispatched }
    end

    context 'when the plan is cancelled' do
      let(:plan_cancelled) { Time.now }

      it { expect(order).not_to be_can_be_dispatched }
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
