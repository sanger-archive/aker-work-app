require 'rails_helper'

RSpec.describe 'WorkPlanSetSpec' do

  let(:user) { build(:user) }
  let(:work_plan) { create(:work_plan) }
  let(:view_model) { ViewModels::WorkPlanSet.new(work_plan: work_plan, user: user) }
  let(:sets) { build_list(:set, 3) }

  describe 'class exists' do
    it 'should allow you to initialize the WorkPlanSet class' do
      expect{ view_model }.not_to raise_error
    end
  end

  describe 'attributes' do

    it 'has #work_plan' do
      expect(view_model.work_plan).to eq(work_plan)
    end

  end

  describe '#form_enabled?' do

    context 'when WorkPlan is in contruction' do
      it 'is true' do
        expect(view_model.form_enabled?).to be true
      end
    end

    context 'when WorkPlan is not in construction' do
      let(:work_plan) { create(:work_plan, status: :active)}

      it 'is false' do
        expect(view_model.form_enabled?).to be false
      end
    end

  end

  describe '#sets' do

    context 'when WorkPlan is in construction' do
      it 'returns a list of non-empty sets from the Set Service belonging to the user' do
        expect(view_model).to receive(:get_non_empty_user_sets).and_return(sets)
        expect(view_model.sets).to eq(sets)
      end
    end

    context 'when WorkPlan is not in construction' do
      let(:work_plan) { create(:work_plan, :with_original_set, status: :active) }
      let(:set) { build(:set) }

      before do
        allow(view_model).to receive(:original_set).and_return(set)
      end

      it 'returns a list containing the original set' do
        expect(view_model.sets).to eq([set])
      end
    end

  end

  describe '#set_names' do
    let(:sets) do
      [build(:set, name: 'Set 1'), build(:set, name: 'SeT 2'), build(:set, name: 'SET 3')]
    end

    before do
      allow(view_model).to receive(:sets).and_return(sets)
    end

    it 'returns the list of Set names downcased' do
      expect(view_model.set_names).to eql(['set 1', 'set 2', 'set 3'])
    end

  end

  describe '#original_set' do

    it 'delegates to the Work Plan' do
      expect(view_model.original_set).to eq(work_plan.decorate.original_set)
    end

  end

end