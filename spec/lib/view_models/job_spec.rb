require 'rails_helper'

RSpec.describe 'ViewModels::Job' do

  let(:job) { create(:completed_job).decorate }
  let(:view_model) { ViewModels::Job.new(job: job) }

  describe 'Job#new' do
    it 'initializes the class' do
      expect{ view_model }.not_to raise_error
    end
  end

  describe '#css_classes' do
    context 'when Job has been forwarded' do
      let(:job) { create(:forwarded_job) }

      it 'is active' do
        expect(view_model.css_classes).to eql("active")
      end
    end

    context 'when Job has not been forwarded' do
      it 'is nil' do
        expect(view_model.css_classes).to be_nil
      end
    end
  end

  describe '#job_id' do
    it 'is the id of the Job' do
      expect(view_model.job_id).to eql(job.id)
    end
  end

  describe '#input_set' do
    before do
      @set = build(:set, id: job.input_set_uuid)
      expect(job).to receive(:input_set).and_return(@set)
    end

    it 'returns the input_set' do
      expect(view_model.job_input_set).to eq(@set)
    end
  end

  describe '#status_label' do
    it 'returns a status label for the Job' do
      expect(view_model.status_label).to_not be_nil
    end
  end

  describe '#concluded_date' do
    context 'when job is completed' do
      let(:job) { create(:completed_job, completed: DateTime.new(2018, 1, 1, 12, 0))}

      it 'returns the formatted completion date' do
        expect(view_model.concluded_date).to eql('01 Jan 12:00')
      end
    end

    context 'when job is cancelled' do
      let(:job) { create(:cancelled_job, cancelled: DateTime.new(2018, 1, 1, 12, 0))}

      it 'returns the formatted cancelled date' do
        expect(view_model.concluded_date).to eql('01 Jan 12:00')
      end
    end
  end

  describe '#output_set' do
    before do
      @set = build(:set, id: job.output_set_uuid)
      expect(job).to receive(:output_set).and_return(@set)
    end

    it 'returns the output set' do
      expect(view_model.job_output_set).to eq(@set)
    end
  end

  describe '#has_revised_set?' do
    context 'when job has a revised set' do
      let(:job) { create(:revised_output_job) }

      it 'returns true' do
        expect(view_model.has_revised_set?).to be true
      end
    end

    context 'when job does not have a revised set' do
      it 'returns false' do
        expect(view_model.has_revised_set?).to be false
      end
    end
  end

  describe '#revised_output_set' do
    let(:job) { create(:revised_output_job).decorate }

    before do
      @set = build(:set, id: job.revised_output_set_uuid)
      expect(job).to receive(:revised_output_set).and_return(@set)
    end

    it 'returns the revised output set' do
      expect(view_model.job_revised_output_set).to eq(@set)
    end
  end

  describe '#job' do
    it 'returns the Job' do
      expect(view_model.job).to eq(job)
    end
  end

  describe '#job_forwarded?' do
    context 'when the job has been forwarded' do
      let(:job) { create(:forwarded_job) }

      it 'returns true' do
        expect(view_model.job_forwarded?).to be true
      end
    end

    context 'when the job has not been forwarded' do
      it 'returns false' do
        expect(view_model.job_forwarded?).to be false
      end
    end
  end

end
