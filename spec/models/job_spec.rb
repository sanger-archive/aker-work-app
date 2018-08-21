# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Job, type: :model do
  context '#validation' do
    it 'is not valid without a work order' do
      expect(build(:job, work_order: nil)).not_to be_valid
    end

    it 'is valid with a work order and uuid' do
      expect(build(:job)).to be_valid
    end

    it 'fails to create a job if there is no work order specified' do
      expect { create :job, work_order: nil }.to raise_exception ActiveRecord::RecordInvalid
    end

  end

  context '#status' do
    let(:job) { create :job }

    it 'checks when the job is broken' do
      job.broken!
      expect(job.status).to eq('broken')
      expect(job).to be_broken
      expect(job.queued?).to eq(false)
      expect(job.active?).to eq(false)
      expect(job.cancelled?).to eq(false)
      expect(job.completed?).to eq(false)
    end

    it 'checks when the job is queued' do
      expect(job.status).to eq('queued')
      expect(job).to be_queued
      expect(job.broken?).to eq(false)
      expect(job.active?).to eq(false)
      expect(job.cancelled?).to eq(false)
      expect(job.completed?).to eq(false)
    end

    it 'checks when the job is active?' do
      job.start!
      expect(job.status).to eq('active')
      expect(job).to be_active
      expect(job.queued?).to eq(false)
      expect(job.broken?).to eq(false)
      expect(job.cancelled?).to eq(false)
      expect(job.completed?).to eq(false)
    end

    it 'checks when the job is completed?' do
      job.start!
      job.complete!
      expect(job.status).to eq('completed')
      expect(job).to be_completed
      expect(job.queued?).to eq(false)
      expect(job.broken?).to eq(false)
      expect(job.active?).to eq(false)
      expect(job.cancelled?).to eq(false)
    end

    it 'checks when the job is cancelled?' do
      job.start!
      job.cancel!
      expect(job.status).to eq('cancelled')
      expect(job).to be_cancelled
      expect(job.queued?).to eq(false)
      expect(job.active?).to eq(false)
      expect(job.completed?).to eq(false)
    end
  end

end
