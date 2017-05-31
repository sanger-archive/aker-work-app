require 'rails_helper'
require 'support/test_services_helper'
require 'completion_cancel_steps/update_work_order_step'

RSpec.describe 'UpdateWorkOrderStep' do
  include TestServicesHelper

  def make_step(work_order, msg, status)
    @step = UpdateWorkOrderStep.new(work_order, msg, status)
  end

  setup do
    @work_order = make_active_work_order
    @any_comment = 'Any comment'
    @msg = { work_order: { comment: @any_comment } } 

    allow(@work_order).to receive(:update_attributes!)
    stub_matcon
  end

  context '#up' do
    it 'should update the work order to complete' do
      make_step(@work_order, @msg, 'complete')    
      attrs = {status: WorkOrder.COMPLETED, comment: @any_comment}
      expect(@work_order).to receive(:update_attributes!).with(attrs)
      @step.up
    end

    it 'should update the work order to cancel' do
      make_step(@work_order, @msg, 'cancel')  
      attrs = {status: WorkOrder.CANCELLED, comment: @any_comment}
      expect(@work_order).to receive(:update_attributes!).with(attrs)
      @step.up
    end
  end

  context '#down' do
    it 'updates the order to ' do
      make_step(@work_order, @msg, 'complete')  
      attrs = {status: make_active_work_order.status, 
        comment: make_active_work_order.comment}
      allow(@step).to receive(:status).and_return(attrs[:status])
      allow(@step).to receive(:comment).and_return(attrs[:comment])
      expect(@work_order).to receive(:update_attributes!).with(attrs)
      @step.down
    end
  end
end