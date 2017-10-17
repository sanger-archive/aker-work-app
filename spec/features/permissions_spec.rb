require 'rails_helper'

RSpec.feature "Permissions", type: :feature do

  let (:work_order) do
    user = OpenStruct.new(email: "user@sanger.ac.uk", groups: ['world'])
    create(:work_order, owner_email: user.email)
  end

  describe 'Work Orders' do
    context 'with a logged in user' do

      before :each do
        @user = OpenStruct.new(email: "bob@sanger.ac.uk", groups: ['world'])
        allow_any_instance_of(JWTCredentials).to receive(:check_credentials)
        allow_any_instance_of(JWTCredentials).to receive(:current_user).and_return(@user)
      end

      context 'when trying to visit an in progress Work Order they do not have read permission on' do
        before :each do
          visit work_order_build_path(work_order_id: work_order.id, id: :product)
        end

        it 'redirects to the root path' do
          expect(page).to have_current_path(root_path)
        end

        it 'displays an error to the user' do
          expect(page).to have_content("not authorized")
        end
      end
    end
  end

end
