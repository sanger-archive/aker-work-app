require 'rails_helper'
require 'support/test_services_helper'
require 'completion_cancel_steps/update_work_order_step'

RSpec.describe 'UpdateWorkOrderStep' do
  include TestServicesHelper


  let(:step) { UpdateWorkOrderStep.new(first_job) }


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
        allow(work_order).to receive(:active?).and_return(true)
      end
      it 'should update the work order to complete' do
        expect(work_order).to receive(:update_attributes!).with(updated_attributes(WorkOrder.CONCLUDED))
        step.up
      end

      it 'should store the old state in the step' do
        old_status = work_order.status
        expect(work_order).to receive(:update_attributes!).with(updated_attributes(WorkOrder.CONCLUDED))
        step.up
        expect(step.old_status).to eq(old_status)
      end
    end
  end

  describe '#down' do
    let(:old_status) { 'active' }

    it 'updates the order to its previous state' do
      allow(step).to receive(:old_status).and_return(old_status)
      expect(work_order).to receive(:update_attributes!).with(status: old_status, completion_date: nil)
      step.down
    end
  end
end
