require 'rails_helper'

RSpec.describe WorkOrdersController, type: :controller do
	describe 'work_order' do
		context 'completion' do
			@msg = FactoryGirl.build(:work_order_completion_message_json)
			@work_order = FactoryGirl.create :work_order
			@msg[:work_order][:work_order_id] = @work_order.id

			it 'completes a work order' do
				debugger
				post complete_work_order_path(@work_order), params: @msg
				expect(@work_order.status).to eq('complete')
			end

			it 'cancels a work order' do
				post cancel_work_order_path(@work_order), params: @msg
				expect(@work_order.status).to eq('cancel')
			end
		end

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
		      wo5 = WorkOrder.create(user_id: user.id, status: WorkOrder.COMPLETED)
		      wo6 = WorkOrder.create(user_id: user2.id, status: WorkOrder.COMPLETED)
			    wo7 = WorkOrder.create(user_id: user.id, status: WorkOrder.CANCELLED)
		      wo8 = WorkOrder.create(user_id: user2.id, status: WorkOrder.CANCELLED)

		      get :index, params: {}

          pending = controller.instance_variable_get("@pending_work_orders")
		      expect(pending.length).to eq 1
		      expect(pending.first).to eq wo1

          active = controller.instance_variable_get("@active_work_orders")
		      expect(active.length).to eq 1
		      expect(active.first).to eq wo3

          completed = controller.instance_variable_get("@completed_work_orders")
		      expect(completed.length).to eq 1

          cancelled = controller.instance_variable_get("@cancelled_work_orders")
		      expect(cancelled.length).to eq 1
			end
		end
	end

end