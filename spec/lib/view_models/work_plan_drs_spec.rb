require 'rails_helper'

RSpec.describe 'ViewModels::WorkPlanDRS' do

  let(:work_plan) { create(:work_plan, :with_project, :with_original_set) }
  let(:user) { build(:user) }
  let(:view_model) { ViewModels::WorkPlanDRS.new(work_plan: work_plan, user: user) }
  let(:drs) { create_list(:data_release_strategy, 3) }

  describe 'class exists' do
    it 'should allow you to initialize the class' do
      expect{ view_model }.not_to raise_error
    end
  end

  describe 'attributes' do
    it 'has work_plan' do
      expect(view_model.work_plan).to eq(work_plan)
    end
  end

  describe '#data_release_strategies' do

    context 'when WorkPlan is in construction' do
      before do
        expect(DataReleaseStrategyClient).to receive(:find_strategies_by_user)
          .with(user.email)
          .and_return(drs)
      end

      it 'returns DRS\'s from the DRSClient' do
        expect(view_model.data_release_strategies).to eq(drs)
      end
    end

    context 'when WorkPlan is not in construction' do
      let(:work_plan) { create(:work_plan, :with_drs, status: :active) }

      it 'returns the selected DRS (in a list)' do
        expect(view_model.data_release_strategies).to eq([work_plan.data_release_strategy])
      end
    end

  end

  describe '#work_plan_drs_id' do
    let(:work_plan) { create(:work_plan, :with_drs, status: :active) }

    it 'is the WorkPlan\'s data_release_strategy_id' do
      expect(view_model.work_plan_drs_id).to eql(work_plan.data_release_strategy_id)
    end
  end

end