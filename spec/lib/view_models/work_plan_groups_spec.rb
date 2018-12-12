require 'rails_helper'

RSpec.describe 'WorkPlanGroupsSpec' do
  let!(:plans_in_construction) { create_list(:work_plan, 2) }
  let!(:active_plans) { create_list(:work_plan, 2, status: :active) }
  let!(:broken_plans) { create_list(:work_plan, 2, status: :broken) }
  let!(:closed_plans) { create_list(:work_plan, 2, status: :closed) }
  let!(:cancelled_plans) { create_list(:work_plan, 2, status: :cancelled) }

  before do
    @groups = ViewModels::WorkPlanGroups.new
  end

  describe 'class exists' do
    it 'should allow you to initialize the WorkPlanGroup class' do
      expect{ ViewModels::WorkPlanGroups.new }.not_to raise_error
    end
  end

  describe '#in_construction' do
    context 'when there are work plans in construction' do
      it 'returns them' do
        expect(@groups.in_construction).to match_array(plans_in_construction)
      end
    end
    context 'when there are no work plans in construction' do
      let!(:plans_in_construction) { }
      it 'should return an empty list' do
        expect(@groups.in_construction).to eq([])
      end
    end
  end

  describe '#active' do
    context 'when there are active work plans' do
      it 'returns them' do
        debugger
        expect(@groups.active).to match_array(active_plans)
      end
    end
    context 'when there are no active work plans' do
      let!(:active_plans) { }
      it 'should return an empty list' do
        expect(@groups.active).to eq([])
      end
    end
  end

  describe '#closed' do
    context 'when there are closed work plans' do
      it 'returns them' do
        expect(@groups.closed).to match_array(closed_plans)
      end
    end
    context 'when there are no closed work plans' do
      let!(:closed_plans) { }
      it 'should return an empty list' do
        expect(@groups.closed).to eq([])
      end
    end
  end

  describe '#cancelled' do
    context 'when there are cancelled work plans' do
      it 'returns them' do
        expect(@groups.cancelled).to match_array(cancelled_plans)
      end
    end
    context 'when there are no cancelled work plans' do
      let!(:cancelled_plans) { }
      it 'should return an empty list' do
        expect(@groups.cancelled).to eq([])
      end
    end
  end

  describe '#any_in_construction?' do
    it 'returns a boolean whether there are plans in construction' do
      expect(@groups.any_in_construction?).to be true
    end
  end

  describe '#any_active?' do
    it 'returns a boolean whether there are active plans' do
      expect(@groups.any_active?).to be true
    end
  end

  describe '#any_closed?' do
    it 'returns a boolean whether there are closed plans' do
      expect(@groups.any_closed?).to be true
    end
  end

  describe '#any_cancelled?' do
    it 'returns a boolean whether there are cancelled plans' do
      expect(@groups.any_cancelled?).to be true
    end
  end
end
