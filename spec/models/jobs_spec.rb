require 'rails_helper'

RSpec.describe 'Jobs', type: :model do
  context '#validation' do
    it 'fails to create a job if there is no work order specified' do
      expect{create :job, work_order: nil}.to raise_exception
    end
  end
  context '#status' do
    let(:job) { create :job}

    it 'checks when the jobs is queued' do
      expect(job.queued?).to eq(true)
      expect(job.active?).to eq(false)
      expect(job.cancelled?).to eq(false)
      expect(job.completed?).to eq(false)
    end

    it 'checks when the job is active?' do
      job.update_attributes(started: Time.now)
      expect(job.queued?).to eq(false)
      expect(job.active?).to eq(true)
      expect(job.cancelled?).to eq(false)
      expect(job.completed?).to eq(false)      
    end

    it 'checks when the job is completed?' do
      job.update_attributes(completed: Time.now)
      expect(job.queued?).to eq(false)
      expect(job.active?).to eq(false)
      expect(job.cancelled?).to eq(false)
      expect(job.completed?).to eq(true)      
    end

    it 'checks when the job is cancelled?' do
      job.update_attributes(cancelled: Time.now)
      expect(job.queued?).to eq(false)
      expect(job.active?).to eq(false)
      expect(job.cancelled?).to eq(true)
      expect(job.completed?).to eq(false)      
    end
  end
end