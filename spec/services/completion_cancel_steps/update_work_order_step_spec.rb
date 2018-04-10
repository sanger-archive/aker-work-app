require 'rails_helper'
require 'support/test_services_helper'
require 'completion_cancel_steps/update_work_order_step'

RSpec.describe 'UpdateWorkOrderStep' do
  include TestServicesHelper

  let(:new_comment) { 'Any comment' }

  let(:step) { UpdateWorkOrderStep.new(first_job, msg) }

  let(:msg) { { job: { comment: new_comment } } }

  def updated_attributes(new_status)
    { status: new_status,  completion_date: Date.today }
  end

  let(:work_order) { make_work_order }

  setup do
    Timecop.freeze(Date.today)
    stub_matcon
  end

  let(:first_job) {
    job = create :job
    job.start!
    job.complete!
    allow(job).to receive(:work_order).and_return(work_order)
    job
  }
  let(:second_job) {
    job = create :job
    job.start!
    job.complete!
    allow(job).to receive(:work_order).and_return(work_order)
    job
  }

  let(:jobs) { [first_job, second_job] }

  describe '#up' do
    context 'when all jobs are completed or cancelled' do
      
      before do
        allow(work_order).to receive(:jobs).and_return(jobs)
        allow(work_order).to receive(:status).and_return(WorkOrder.ACTIVE)

      end
      it 'should update the work order to complete' do
        expect(work_order).to receive(:update_attributes!).with(updated_attributes(WorkOrder.CONCLUDED))
        expect(first_job).to receive(:update_attributes!).with(close_comment: new_comment)
        step.up
      end

      it 'should store the old state in the step' do
        old_status = work_order.status
        old_close_comment = first_job.close_comment
        expect(work_order).to receive(:update_attributes!).with(updated_attributes(WorkOrder.CONCLUDED))
        expect(first_job).to receive(:update_attributes!).with(close_comment: new_comment)
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
      expect(work_order).to receive(:update_attributes!).with(status: old_status)
      expect(first_job).to receive(:update_attributes!).with(close_comment: old_comment)
      step.down
    end
  end
end
