require 'rails_helper'

RSpec.describe 'StudyClientSpec' do

  context '#get_spendable_projects' do
    let(:user) { OpenStruct.new(email: 'jeff@sanger.ac.uk', groups: ['world']) }
    let(:project1) { double(:project, id: 12) }
    let(:project2) { double(:project, id: 13) }

    before do
      allow(StudyClient::Node).to receive(:where).and_return(OpenStruct.new(all: [project1, project1, project2 ]))
    end

    it 'should return a list of unique projects' do
      result = StudyClient.get_spendable_projects(user)
      expect(result).to eq([project1, project2])
    end
  end

  context '#current_user_has_spend_permission_on_project' do
    before do
      allow(StudyClient::Node).to receive(:where).and_return(OpenStruct.new(all: [project]))
    end

    context 'when user has spend permission' do
      let(:user) { OpenStruct.new(email: 'jeff@sanger.ac.uk', groups: ['world']) }
      let(:project) { OpenStruct.new(id: 12, 'spendable-by-current-user': true) }

      it 'should return true' do
        result = StudyClient.current_user_has_spend_permission_on_project(project.id)
        expect(result).to eq(true)
      end
    end
    context 'when user does not have spend permission' do
      let(:user) { OpenStruct.new(email: 'jeff@sanger.ac.uk', groups: ['world']) }
      let(:project) { OpenStruct.new(id: 12, 'spendable-by-current-user': false) }

      it 'should return true' do
        result = StudyClient.current_user_has_spend_permission_on_project(project.id)
        expect(result).to eq(false)
      end
    end

  end

  context '#user_and_groups_list' do
    let(:user) { OpenStruct.new(email: 'jeff@sanger.ac.uk', groups: ['world']) }

    it 'should return the users email and groups' do
      result = StudyClient.user_and_groups_list(user)
      expected = [user.email, 'world']
      expect(result).to eq(expected)
    end
  end
end
