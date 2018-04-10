require 'rails_helper'
require 'support/test_services_helper'
require 'completion_cancel_steps/update_job_step'

RSpec.describe 'UpdateJobStep' do
  include TestServicesHelper

  let(:job) { create :job, started: Time.now }
  let(:new_comment) { 'Any comment' }
  let(:msg) { { job: { comment: new_comment } } }
  let(:step) { UpdateJobStep.new(job, msg, 'complete') }
  context '#up' do
    it 'sets the close comment and status' do
      step.up
      expect(job.status).to eq('completed')
      expect(job.close_comment).to eq(new_comment)
    end
  end
  context '#down' do
    it 'reverts the close comment and status' do
      step.up
      step.down
      expect(job.status).to eq('active')
      expect(job.close_comment).to eq(nil)
    end    
  end
end