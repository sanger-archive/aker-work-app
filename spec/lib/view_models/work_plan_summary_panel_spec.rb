require 'rails_helper'

RSpec.describe 'ViewModels::WorkPlanSummaryPanel' do

  let(:work_plan) { create(:startable_work_plan).decorate }
  let(:view_model) { ViewModels::WorkPlanSummaryPanel.new(work_plan: work_plan) }
  let(:set) { build(:set, id: work_plan.original_set_uuid) }
  let(:project) { build(:project, id: work_plan.project_id) }

  describe 'WorkPlanSummaryPanel#new' do
    it 'initializes the class' do
      expect{ view_model }.not_to raise_error
    end
  end

  describe 'attributes' do
    it 'has work_plan' do
      expect(view_model.work_plan).to eq(work_plan)
    end
  end

  describe '#work_plan_id' do
    it 'returns the Work Plan\'s ID' do
      expect(view_model.work_plan_id).to eq(work_plan.id)
    end
  end

  describe '#created_at' do
    let(:work_plan) { create(:work_plan, created_at: DateTime.new(2018,1,1)) }

    it 'returns a formatted created_at datetime' do
      expect(view_model.created_at).to eql('01/01/18')
    end
  end

  describe '#owner_email' do
    it 'returns the Work Plan owner\'s email' do
      expect(view_model.owner_email).to eql(work_plan.owner_email)
    end
  end

  describe '#original_set_name' do

    before do
      allow(work_plan).to receive(:original_set).and_return(set)
    end

    it 'returns a set from the Set Service' do
      expect(view_model.original_set_name).to eq(set.name)
    end

  end

  describe '#product_name' do
    it 'returns the name of the Work Plan\'s Product' do
      expect(view_model.product_name).to eq(work_plan.product.name)
    end
  end

  describe '#project_name' do

    before do
      allow(work_plan).to receive(:project).and_return(project)
    end

    it 'returns the name of the Work Plan\'s Project' do
      expect(view_model.project_name).to eq(project.name)
    end
  end

  describe '#cost_code' do

    before do
      allow(work_plan).to receive(:project).and_return(project)
    end

    it 'returns the cost_code of the Work Plan\'s Project' do
      expect(view_model.cost_code).to eq(project.cost_code)
    end
  end

  describe '#data_release_strategy' do
    it 'returns the Work Plan\'s Data Release Strategy name' do
      expect(view_model.data_release_strategy).to eq(work_plan.data_release_strategy.name)
    end
  end

end