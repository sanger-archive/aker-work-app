require 'rails_helper'

RSpec.describe WorkOrdersController, type: :controller do
  def setup_user(name = "user")
    user = OpenStruct.new(email: "#{name}@sanger.ac.uk", groups: ['world'])
    allow(controller).to receive(:current_user).and_return(user)
    return user
  end

  describe '#create' do
    context 'when user creates a work order' do
      it 'creates a work order with the logged on user' do
        user = setup_user

        expect { post :create, params: {} }.to change(WorkOrder, :count).by(1)
        work_order = WorkOrder.last
        expect(work_order.owner_email).to eq user.email
        expected_redirect = work_order_build_url(
          id: Wicked::FIRST_STEP,
          work_order_id: work_order.id
        )
        expect(response.redirect_url).to eq(expected_redirect)
        expect(response).to have_http_status(:found)
      end
    end
  end

  describe "#index" do
    context "when the user is logged in" do
      it 'shows work orders belonging to the user' do
        user = setup_user
        user2 = OpenStruct.new(email: 'jeff@sanger.ac.uk', groups: ['world'])
        wo1 = WorkOrder.create(owner_email: user.email, status: "product")
        wo2 = WorkOrder.create(owner_email: user2.email, status: "product")
        wo3 = WorkOrder.create(owner_email: user.email, status: WorkOrder.ACTIVE)
        wo4 = WorkOrder.create(owner_email: user2.email, status: WorkOrder.ACTIVE)

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

  describe "#get" do
    context 'when the work order exists' do
      it 'renders the work order json' do
        user = setup_user("jeff")
        wo = WorkOrder.create(owner_email: user.email, status: WorkOrder.ACTIVE)
        data = {alpha: :beta}
        expect_any_instance_of(WorkOrder).to receive(:lims_data).and_return(data)
        get :get, params: { id: wo.id }
        expect(response).to have_http_status(:ok)
        expect(response.redirect_url).to be_nil
        expect(response.body).to eq(data.to_json)
      end
    end
    context 'when the work order does not exist' do
      it 'returns 404' do
        setup_user
        get :get, params: { id: 0 }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "#destroy" do
    context "when the work order is destructible" do
      before do
        user = setup_user
        @wo = WorkOrder.create(owner_email: user.email, status: "product")

        delete :destroy, params: { id: @wo.id }
      end
      it 'deletes the work order' do
        expect(WorkOrder.find_by(id: @wo.id)).to be_nil
      end
      it 'shows a suitable message' do
        expect(flash[:notice]).to include("order cancelled")
      end
      it 'redirects' do
        expect(response.redirect_url).to eq work_orders_url
      end
    end

    context "when the work order has already been issued" do
      before do
        user = setup_user
        @wo = WorkOrder.create(owner_email: user.email, status: 'active')

        delete :destroy, params: { id: @wo.id }
      end
      it 'does not delete the work order' do
        expect(WorkOrder.find_by(id: @wo.id)).to eq(@wo)
      end
      it 'shows an error message' do
        expect(flash[:error]).to include 'cannot be cancelled'
      end
      it 'redirects' do
        expect(response.redirect_url).to eq work_orders_url
      end
    end

    context "when the work order belongs to someone else" do
      before do
        user = setup_user
        user2 = OpenStruct.new(email: 'jeff@sanger.ac.uk', groups: ['world'])
        @wo = WorkOrder.create(owner_email: user2.email, status: 'product')

        delete :destroy, params: { id: @wo.id }
      end
      it 'does not delete the work order' do
        expect(WorkOrder.find_by(id: @wo.id)).to eq(@wo)
      end
      it 'shows an auth alert' do
        expect(flash[:alert]).to match(/not authori[sz]ed/)
      end
    end
  end

  describe "#show" do
    context "when the work order belongs to the current user" do
      it "succeeds" do
        user = setup_user
        @wo = WorkOrder.create(owner_email: user.email)

        get :show, params: { id: @wo.id }

        expect(response).to have_http_status(:ok)
        expect(flash[:alert]).to be_nil
        expect(response.redirect_url).to be_nil
      end
    end

    context "when the work order belongs to someone else" do
      it "still succeeds" do
        user = setup_user
        user2 = OpenStruct.new(email: 'jeff@sanger.ac.uk', groups: ['world'])
        @wo = WorkOrder.create(owner_email: user2.email)

        get :show, params: { id: @wo.id }

        expect(response).to have_http_status(:ok)
        expect(flash[:alert]).to be_nil
        expect(response.redirect_url).to be_nil
      end
    end
  end

end
