require 'rails_helper'

RSpec.describe 'ForUserQuerySpec' do
  let(:user1) { OpenStruct.new(email: 'user1@here', groups: ['world']) }
  let(:user2) { OpenStruct.new(email: 'user2@here', groups: ['world']) }
  let(:plan1) { create(:work_plan, owner_email: user1.email) }
  let(:plan2) { create(:work_plan, owner_email: user2.email) }
  let(:plan3) { create(:work_plan, owner_email: user2.email) }

  describe 'initialize' do
    it 'does not fail' do
      expect{ WorkPlans::ForUserQuery.new }.not_to raise_error
    end
  end

  describe '#call' do
    it 'returns the work plans for the user' do
      expect(WorkPlans::ForUserQuery.call(user2)).to eq [plan2, plan3]
    end
  end
end
