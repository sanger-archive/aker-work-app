require 'rails_helper'
require 'support/test_services_helper'
require 'completion_cancel_steps/update_work_order_step'

RSpec.describe 'UpdateWorkOrderStep' do
  include TestServicesHelper

  let(:new_comment) { 'Any comment' }
  let(:mode) { 'complete' }
  let(:work_order) do
    wo = make_active_work_order
    allow(wo).to receive(:update_attributes!)
    wo
  end

  let(:step) { UpdateWorkOrderStep.new(work_order, msg, mode) }

  let(:msg) { { work_order: { comment: new_comment } } }

  def updated_attributes(new_status)
    { status: new_status, close_comment: new_comment, completion_date: Date.today }
  end

  setup do
    stub_matcon
  end

  describe '#up' do
    context 'when completing' do
      let(:mode) { 'complete' }

      it 'should update the work order to complete' do
        expect(work_order).to receive(:update_attributes!).with(updated_attributes(WorkOrder.COMPLETED))
        step.up
      end

      it 'should store the old state in the step' do
        old_status = work_order.status
        old_close_comment = work_order.close_comment
        step.up
        expect(step.old_status).to eq(old_status)
        expect(step.old_close_comment).to eq(old_close_comment)
      end
    end

    context 'when cancelling' do
      let(:mode) { 'cancel' }

      it 'should update the work order to cancelled' do
        expect(work_order).to receive(:update_attributes!).with(updated_attributes(WorkOrder.CANCELLED))
        step.up
      end
      it 'should store the old state in the step' do
        old_status = work_order.status
        old_close_comment = work_order.close_comment
        step.up
        expect(step.old_status).to eq(old_status)
        expect(step.old_close_comment).to eq(old_close_comment)
      end
    end
  end

  describe '#down' do
    let(:old_status) { 'active' }
    let(:old_comment) { 'some old comment' }

    it 'updates the order to its previous state' do
      allow(step).to receive(:old_status).and_return(old_status)
      allow(step).to receive(:old_close_comment).and_return(old_comment)
      expect(work_order).to receive(:update_attributes!).with(status: old_status, close_comment: old_comment)
      step.down
    end
  end
end
