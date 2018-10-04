require 'rails_helper'

RSpec.feature "Permissions", type: :feature do

  describe 'Work Plans' do
    context '#show' do
      context 'when trying to visit a Work Plan they have spendable permission on' do
        let(:user) { OpenStruct.new(email: "bob@sanger.ac.uk", groups: ['world']) }

        before do
          allow_any_instance_of(JWTCredentials).to receive(:check_credentials)
          allow_any_instance_of(JWTCredentials).to receive(:current_user).and_return(user)
        end

        context 'when the plan is in constuction' do
          let (:work_plan) { create(:work_plan, owner_email: 'owner@here') }

          before do
            allow(work_plan).to receive(:in_construction?).and_return(true)
            allow(Study).to receive(:spendable_projects).with(user).and_return([])
            visit work_plan_build_path(work_plan_id: work_plan.id, id: 'set')
          end

          it 'redirects to the root path' do
            expect(page).to have_current_path(root_path)
          end

          it 'displays an error to the user' do
            expect(page).to have_content("You are not authorized to access this page.")
          end
        end

        context 'when the plan is active' do
          let(:set) { double("SetClient::Set", uuid: 12, name: 'a set') }
          let(:project) { double(:project, id: 12, name: 'a project') }
          let(:work_plan) { create(:work_plan, status: :active) }

          before do
            allow(Study).to receive(:current_user_has_spend_permission_on_project?).and_return true
            visit work_plan_build_path(work_plan_id: work_plan.id, id: 'product')
          end

          it 'allows user to redirects to the plan path' do
            expect(page).not_to have_current_path(root_path)
          end
        end
      end
    end
  end
end
