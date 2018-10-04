require 'rails_helper'

RSpec.describe 'ModifiableByUserQuerySpec' do
  describe 'initialize' do
    it 'does not fail' do
      expect { WorkPlans::ModifiableByUserQuery.new }.not_to raise_error
    end
  end

  describe '#call' do
    let(:user1) { OpenStruct.new(email: 'user1@here', groups: ['world']) }
    let(:user2) { OpenStruct.new(email: 'user2@here', groups: ['world']) }
    let(:project1) { double(:project, id: 1) }
    let(:project2) { double(:project, id: 2) }
    let(:plan1) { create(:work_plan, owner_email: user1.email) }
    let(:plan2) { create(:work_plan, owner_email: user2.email) }
    let(:plan3) { create(:work_plan, owner_email: user2.email, project_id: project1.id) }

    it 'returns the work plans where the user has modifiable permission' do
      allow(Study).to receive(:spendable_projects).with(user1).and_return [project1, project2]
      expect(WorkPlans::ModifiableByUserQuery.call(user1)).to eq [plan1, plan3]
    end
  end
end
