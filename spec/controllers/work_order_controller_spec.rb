require 'rails_helper'

RSpec.describe WorkOrdersController, type: :controller do
	describe 'work_order' do
		context '#new' do
			it 'creates a work order with the logged on user' do
		      @request.env['devise.mapping'] = Devise.mappings[:user]

		      groups = ["cowboys"]

		      user = create(:user)
		      sign_in user

		      expect { post :create, params: {} }.to change(WorkOrder, :count).by(1)
	          expect(WorkOrder.last.user_id).to eq user.id

			end
		end

		context "#index" do
			it 'shows work orders belonging to the user' do
				@request.env['devise.mapping'] = Devise.mappings[:user]

		      groups = ["cowboys"]

		      user = create(:user)
		      sign_in user
		      user2 = create(:user, email: 'jeff@sanger.ac.uk')
		      wo1 = WorkOrder.create(user_id: user.id, status: "product")
		      wo2 = WorkOrder.create(user_id: user2.id, status: "product")
		      wo3 = WorkOrder.create(user_id: user.id, status: WorkOrder.ACTIVE)
		      wo4 = WorkOrder.create(user_id: user2.id, status: WorkOrder.ACTIVE)

		      get :index, params: {}

              pending = controller.instance_variable_get("@pending_work_orders")
		      expect(pending.length).to eq 1
		      expect(pending.first).to eq wo1
              active = controller.instance_variable_get("@active_work_orders")
		      expect(active.length).to eq 1
		      expect(active.first).to eq wo3
			end
		end
	end

end