require 'rails_helper'

RSpec.feature "Permissions", type: :feature do

  let(:work_order) { create(:work_order, user: create(:user)) }

  describe 'Work Orders' do
    context 'with a logged in user' do

      before :each do
        sign_in create(:user)
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
