require 'rails_helper'

RSpec.describe WorkOrderDispatcher do

  let(:work_order_dispatcher) { WorkOrderDispatcher.new }
  let(:work_plan) { create(:work_plan, product: create(:product)) }
  let(:work_order) { create(:work_order_with_jobs, work_plan: work_plan) }

  describe '#initialize' do

    it 'sets a default serializer' do
      expect(work_order_dispatcher.serializer).to be_instance_of(WorkOrderSerializer)
    end

    it 'sets a default policy' do
      expect(work_order_dispatcher.policy).to be_instance_of(DispatchableWorkOrderPolicy)
    end

  end

  describe '#dispatch' do

    context 'when DispatchWorkOrderPolicy#dispatchable? returns false' do
      let(:dispatch_errors) do
        dispatch_errors = ActiveModel::Errors.new(Job.new)
        dispatch_errors.add(:uuid)
        dispatch_errors
      end

      before :each do
        allow(work_order_dispatcher.policy).to receive(:dispatchable?).and_return(false)
        allow(work_order_dispatcher.policy).to receive(:errors).and_return(dispatch_errors)
      end

      it 'returns false' do
        expect(work_order_dispatcher.dispatch(work_order)).to be false
      end

      it 'merges the errors from the policy' do
        work_order_dispatcher.dispatch(work_order)
        expect(work_order_dispatcher.errors.empty?).to be false
      end

    end

    context 'when valid' do

      before :each do
        # Work Order is dispatchable
        allow(work_order_dispatcher.policy).to receive(:dispatchable?).and_return(true)
        # It sets materials availability to false
        expect(work_order_dispatcher).to receive(:set_materials_availability).with(false)
        # It serializes the Work Order
        expect(work_order_dispatcher.serializer).to receive(:serialize).with(work_order).and_return({})
        # It sends the Work Order to the Lims Client
        expect(LimsClient).to receive(:post).with(work_plan.product.catalogue.job_creation_url, {})
      end

      it 'sets the work_order dispatch_date' do
        expect { work_order_dispatcher.dispatch(work_order) }.to change(work_order, :dispatch_date)
      end

      it 'sets the work_order status to active' do
        expect { work_order_dispatcher.dispatch(work_order) }.to change(work_order, :status).to("active")
      end

      context 'when sending to LIMS fails' do

        before :each do
          expect(work_order_dispatcher).to receive(:set_materials_availability).with(true)
          allow(LimsClient).to receive(:post).and_raise(StandardError, 'Sending to LIMS failed')
        end

        it 'returns false' do
          expect(work_order_dispatcher.dispatch(work_order)).to be false
        end

        it 'sets an error message' do
          work_order_dispatcher.dispatch(work_order)
          expect(work_order_dispatcher.errors.full_messages_for(:base)).to eql(['Sending to LIMS failed'])
        end

      end
    end
  end

end
