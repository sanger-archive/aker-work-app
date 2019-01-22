require 'rails_helper'

RSpec.describe DispatchWorkOrder, type: :job do

  let(:work_order) { create(:work_order_with_jobs) }
  let(:enqueue) { DispatchWorkOrder.enqueue(work_order_id: work_order.id) }

  describe 'DispatchWorkOrder#enqueue' do

    it 'enqueues a DispatchWorkOrder job' do
      expect { enqueue }.to change { QueJob.count }.by(1)
      expect(QueJob.last.job_class).to eql("DispatchWorkOrder")
    end

  end

  describe '#run' do

    # Immediately execute the job
    # See https://github.com/chanks/que#testing
    before do
      Que::Job.run_synchronously = true
    end

    after do
      Que::Job.run_synchronously = false
    end

    context 'when the Broker is not working' do
      before do
        stub_const('BrokerHandle', class_double('BrokerHandle', events_enabled?: true, working?: false))
      end

      it 'raises DispatchWorkOrder::BrokerNotWorkingError' do
        error_message = /Work Order #{work_order.id} could not be dispatched./
        expect { enqueue }.to raise_error(DispatchWorkOrder::BrokerNotWorkingError, error_message)
          .and change { ActionMailer::Base.deliveries.count }.by(1)
      end

    end

    context 'when WorkOrderDispatcher#dispatch returns false' do

      before do
        allow_any_instance_of(WorkOrderDispatcher).to receive(:dispatch).and_return(false)
      end

      it 'raises a DispatchWorkOrder::DispatchError' do
        error_message = /Work Order #{work_order.id} could not be dispatched./
        expect { enqueue }.to raise_error(DispatchWorkOrder::DispatchError, error_message)
          .and change { ActionMailer::Base.deliveries.count }.by(1)
      end

      context 'when this was the final attempt' do

        before do
          allow_any_instance_of(DispatchWorkOrder).to receive(:is_final_attempt?).and_return(true)
        end

        it 'sets the Work Order to broken' do
          expect { enqueue }.to raise_error(DispatchWorkOrder::DispatchError)
            .and change { work_order.reload.broken? }.from(false).to(true)
            .and change { ActionMailer::Base.deliveries.count }.by(2)
        end

      end

    end

    context 'when WorkOrderDispatcher#dispatch returns true' do

      before do
        allow_any_instance_of(DispatchWorkOrder).to receive(:work_order).and_return(work_order)
        allow_any_instance_of(WorkOrderDispatcher).to receive(:dispatch).and_return(true)
      end

      it 'sends a dispatched event' do
        expect(work_order).to receive(:generate_dispatched_event)
        enqueue
      end

      it 'notifies the user of the successful dispatch' do
        expect { enqueue }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

    end

  end

end