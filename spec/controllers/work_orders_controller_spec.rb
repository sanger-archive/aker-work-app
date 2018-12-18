require 'rails_helper'

RSpec.describe WorkOrdersController, type: :controller do
  let!(:user) { setup_user }

  before do
    stub_const('BrokerHandle', class_double('BrokerHandle'))
  end

  def setup_user(name = "user")
    user = OpenStruct.new(email: "#{name}@sanger.ac.uk", groups: ['world'])
    allow(controller).to receive(:check_credentials)
    allow(controller).to receive(:current_user).and_return(user)
    return user
  end

  describe "#get" do
    context 'when the work order exists' do
      it 'renders the work order json' do
        order = create(:work_order)

        expect(WorkOrder).to receive(:find).with(order.id.to_s).and_return order
        data = {alpha: :beta}
        expect_any_instance_of(WorkOrder).to receive(:lims_data_for_get).and_return(data)

        params = { id: order.id}
        get :get, params: params

        expect(response).to have_http_status(:ok)
        expect(response.redirect_url).to be_nil
        expect(response.body).to eq(data.to_json)
      end
    end
    context 'when the work order does not exist' do
      it 'returns 404' do
        get :get, params: { id: 0 }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

end
