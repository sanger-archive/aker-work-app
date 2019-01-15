require 'rails_helper'

RSpec.describe 'WorkPlanProjectSpec' do

  let(:user) { build(:user) }
  let(:work_plan) { create(:work_plan) }
  let(:view_model) { ViewModels::WorkPlanProject.new(work_plan: work_plan, user: user) }

  describe 'class exists' do
    it 'should allow you to initialize the WorkPlanProject class' do
      expect{ view_model }.not_to raise_error
    end
  end

  describe 'attributes' do
    it 'has work_plan' do
      expect(view_model.work_plan).to eq(work_plan)
    end
  end

  describe '#projects' do
    it 'returns spendable projects for a user' do
      expect(Study).to receive(:spendable_projects).with(user)
      view_model.projects
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

end