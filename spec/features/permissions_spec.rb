require 'rails_helper'

RSpec.feature "Permissions", type: :feature do

  describe 'Work Plans' do
    before do
      @user = OpenStruct.new(email: "bob@sanger.ac.uk", groups: ['world'])
      allow_any_instance_of(JWTCredentials).to receive(:check_credentials)
      allow_any_instance_of(JWTCredentials).to receive(:current_user).and_return(@user)
    end
    context 'when trying to visit a Work Plan they do not have read permission on' do
      let (:work_plan) { create(:work_plan) }

      before do
        visit work_plan_build_path(work_plan_id: work_plan.id, id: 'set')
      end

      it 'redirects to the root path' do
        expect(page).to have_current_path(root_path)
      end

      it 'displays an error to the user' do
        expect(page).to have_content("You are not authorized to access this page.")
      end
    end
  end

end
