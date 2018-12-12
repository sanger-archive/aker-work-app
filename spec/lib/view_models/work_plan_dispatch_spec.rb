require 'rails_helper'

RSpec.describe 'ViewModels::WorkPlanDispatch' do

  let(:work_plan) { create(:startable_work_plan).decorate }
  let(:view_model) { ViewModels::WorkPlanDispatch.new(work_plan: work_plan) }

  describe 'WorkPlanDispatch#new' do
    it 'initializes the class' do
      expect{ view_model }.not_to raise_error
    end
  end

  describe 'attributes' do
    it 'has work_plan' do
      expect(view_model.work_plan).to eq(work_plan)
    end
  end

  describe '#summary_panel' do
    it 'returns an instance of ViewModels::WorkPlanSummaryPanel' do
      expect(view_model.summary_panel).to be_an_instance_of(ViewModels::WorkPlanSummaryPanel)
    end
  end

  describe '#form_enabled?' do
    context 'when Work Plan is in construction' do
      it 'is true' do
        expect(view_model.form_enabled?).to be true
      end
    end

    context 'when Work Plan is not in construction' do
      let(:work_plan) { create(:work_plan, status: :active) }

      it 'is false' do
        expect(view_model.form_enabled?).to be false
      end
    end
  end

  describe '#processes' do
    it 'returns a list of ViewModels::WorkPlanProcess objects' do
      expect(view_model.processes).to all be_an_instance_of(ViewModels::WorkPlanProcess)
    end
  end

end