require 'rails_helper'

RSpec.describe 'ViewModels::WorkOrder' do

  let(:work_order) { create(:work_order) }
  let(:jobs) { create_list(:completed_job, 3) + create_list(:forwarded_job, 3) }
  let(:view_model) { ViewModels::WorkOrder.new(work_order: work_order, jobs: jobs) }

  describe 'WorkOrder#new' do
    it 'initializes the class' do
      expect{ view_model }.not_to raise_error
    end
  end

  describe '#work_order_id' do
    it 'is the Work Order id' do
      expect(view_model.work_order_id).to eql(work_order.id)
    end
  end

  describe '#dispatch_date' do
    let(:work_order) { create(:work_order, dispatch_date: DateTime.new(2018,1,1,12,0)) }

    it 'returns the Work Order\'s formatted dispatch date' do
      expect(view_model.dispatch_date).to eql('01 Jan 12:00')
    end
  end

  describe '#completion_date' do
    context 'when Work Order is concluded' do
      let(:work_order) { create(:closed_work_order, completion_date: DateTime.new(2018,1,1,14,0)) }

      it 'is the formatted completion date' do
        expect(view_model.completion_date).to eql('Completion Date: 01 Jan 14:00')
      end
    end

    context 'when Work Order is not concluded' do
      before do
        allow(work_order).to receive(:estimated_completion_date).and_return(DateTime.new(2019,1,10,12,0))
      end

      it 'is the formatted estimated_completition_date' do
        expect(view_model.completion_date).to eql('Estimated Completion Date: 10 Jan 12:00')
      end
    end
  end

  describe '#number_of_jobs' do
    it 'is the number of Jobs in the Work Order' do
      expect(view_model.number_of_jobs).to eql(work_order.jobs.size)
    end
  end

  describe '#show_jobs?' do
    context 'when there are Jobs' do
      it 'is true' do
        expect(view_model.show_jobs?).to be true
      end
    end

    context 'when there are no Jobs' do
      let(:jobs) { [] }

      it 'is false' do
        expect(view_model.show_jobs?).to be false
      end
    end
  end

  describe '#jobs' do
    it 'returns a list of ViewModel::Job objects' do
      expect(view_model.jobs).to all be_an_instance_of(ViewModels::Job)
    end
  end

end