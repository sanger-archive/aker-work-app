require 'rails_helper'

RSpec.describe 'WorkPlanPermissionPolicy' do
  describe 'can initialize a user policy class' do
    let(:user) { OpenStruct.new(email: 'user@here', groups: []) }
    let(:plan) { create(:work_plan) }

    it 'raises an error if you dont pass a user' do
      expect{ WorkPlanPermissionPolicy.new(plan) }.to raise_error
    end

    it 'raises an error if you dont pass a work plan' do
      expect{ WorkPlanPermissionPolicy.new(user) }.to raise_error
    end

    it 'does not raise an error if you pass a user and a work plan' do
      expect{ WorkPlanPermissionPolicy.new(user, plan) }.not_to raise_error
    end
  end

  describe '#permitted?' do
    let(:user) { OpenStruct.new(email: 'user@here', groups: ['pirates']) }
    let(:plan) { create(:work_plan) }
    let(:active_plan) { create(:work_plan, status: :active) }
    let(:plan_with_owner) { create(:work_plan, owner_email: user.email) }
    let(:plan_with_owner_in_group) { create(:work_plan, owner_email: 'pirates') }

    it 'returns true if access is read' do
      policy_for_plan = WorkPlanPermissionPolicy.new(user, plan)
      expect(policy_for_plan.permitted?(:read)).to eq true
    end

    it 'returns true if access is create' do
      policy_for_plan = WorkPlanPermissionPolicy.new(user, plan)
      expect(policy_for_plan.permitted?(:create)).to eq true
    end

    it 'returns true if user is the owner of the plan' do
      policy_for_plan_with_owner = WorkPlanPermissionPolicy.new(user, plan_with_owner)
      expect(policy_for_plan_with_owner.permitted?(:write)).to eq true
    end

    it 'returns true if one of the users groups is the owner of the plan' do
      policy_for_plan_with_owner_in_group = WorkPlanPermissionPolicy.new(user, plan_with_owner_in_group)
      expect(policy_for_plan_with_owner_in_group.permitted?(:write)).to eq true
    end

    it 'returns true if users can modify the plan' do
      allow(Study).to receive(:current_user_has_spend_permission_on_project?).with(active_plan.project_id).and_return(true)
      policy_for_plan_with_modifiable_user = WorkPlanPermissionPolicy.new(user, active_plan)
      expect(policy_for_plan_with_modifiable_user.permitted?(:write)).to eq true
    end
  end
end
