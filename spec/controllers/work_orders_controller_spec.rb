require 'rails_helper'

RSpec.describe WorkOrdersController, type: :controller do
  let!(:user) { setup_user }

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

  describe '#complete' do
    let(:project) do
      proj = double(:project, id: 17, cost_code: 'S1234-0')
      allow(StudyClient::Node).to receive(:find).with(proj.id).and_return([proj])
      proj
    end
    let(:work_plan) { create(:work_plan, project_id: project.id) }

    let(:order) { create(:work_order, work_plan: work_plan) }
    let(:params) do
      {
        id: order.id,
        work_order: {
          work_order_id: order.id,
        },
      }
    end

    context 'when the work order is valid' do
      before do
        allow_any_instance_of(WorkOrderValidatorService).to receive(:validate?).and_return(true)
        allow_any_instance_of(DispatchService).to receive(:process).and_return(true)
        post :complete, params: params
      end

      it 'should put the user in the request store' do
        xauth = RequestStore.store[:x_authorisation]
        expect(xauth).not_to be_nil
        expect(xauth[:email]).to eq(work_plan.owner_email)
      end

      it { expect(response).to have_http_status(:ok) }

      it 'should have correct message in repsonse body' do
        msg = "Your work order is completed"
        expect(response.body).to eq({message: msg}.to_json)
      end

      it 'should add appropriate JWT to outgoing requests' do
        serializer = JWTSerializer.new
        app_double = double('app')
        expect(app_double).to receive(:call)
        serializer.instance_variable_set(:@app, app_double)
        request_headers = {}
        serializer.call(request_headers: request_headers)
        coded_jwt = request_headers['X-Authorisation']
        expect(coded_jwt).not_to be_nil
        payload, _ = JWT.decode coded_jwt, Rails.application.config.jwt_secret_key, true, algorithm: 'HS256'
        expect(payload).not_to be_nil
        expect(payload["data"]["email"]).to eq(work_plan.owner_email)
      end
    end

    context 'when the work order is not valid' do
      before do
        allow_any_instance_of(WorkOrderValidatorService).to receive(:validate?).and_return(false)
        allow_any_instance_of(WorkOrderValidatorService).to receive(:errors).and_return({msg: "Your work order is not completed"})

        post :complete, params: params
      end

      it 'should put the user in the request store' do
        xauth = RequestStore.store[:x_authorisation]
        expect(xauth).not_to be_nil
        expect(xauth[:email]).to eq(work_plan.owner_email)
      end

      it { expect(response).to have_http_status(:ok) }

      it 'should have correct message in repsonse body' do
        msg = "Your work order is not completed"
        expect(response.body).to eq({message: msg}.to_json)
      end
    end

  end

end
