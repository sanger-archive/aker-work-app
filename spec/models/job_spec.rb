# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Job, type: :model do
  describe '#validation' do
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

  describe '#name' do
    it 'should be correct' do
      job = create(:job)
      expect(job.name).to eq("Job #{job.id}")
    end
  end

  describe '#status' do
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

  describe '#generate_concluded_event' do
    let(:job) { create(:job) }

    let(:broker) do
      brok = class_double('BrokerHandle')
      stub_const('BrokerHandle', brok)
      brok
    end

    let(:message) { class_double('JobEventMessage') }

    context 'when the broker works' do
      it 'should construct and send the message correctly' do
        expect(JobEventMessage).to receive(:new).with(job: job, status: 'effulgent').and_return(message)
        expect(broker).to receive(:publish).with(message)

        job.generate_concluded_event('effulgent')
      end
    end

    context 'when the broker does not work' do
      it 'should construct and attempt to send the message and log the exception' do
        expect(JobEventMessage).to receive(:new).with(job: job, status: 'effulgent').and_return(message)
        error = RuntimeError.new("This will not be published.")
        expect(broker).to receive(:publish).with(message).and_raise error
        allow(Rails.logger).to receive(:error)

        job.generate_concluded_event('effulgent')

        expect(Rails.logger).to have_received(:error).with error
        expect(Rails.logger).to have_received(:error).with error.backtrace
      end
    end
  end

end
