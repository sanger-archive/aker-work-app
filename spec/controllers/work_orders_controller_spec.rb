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


  describe '#create_editable_set' do
    let(:plan) { create(:work_plan, owner_email: user.email) }
    let(:status) { :queued }
    let(:set) do
      uuid = SecureRandom.uuid
      double(:set, name: 'My set', id: uuid, uuid: uuid)
    end
    let(:original_set_uuid) { set.uuid }
    let(:set_uuid) { nil }
    let(:work_order) { create(:work_order, work_plan: plan, status: status, original_set_uuid: original_set_uuid, set_uuid: set_uuid) }
    let(:params) { { id: work_order.id } }
    let(:data) { JSON.parse(response.body, symbolize_names: true) }

    def setup
    end

    before do
      setup
      post :create_editable_set, params: params
    end

    context 'when the work order is not queued' do
      let(:status) { :active }
      it 'should produce an error' do
        expect(data[:error]).to eq("This work order cannot be modified.")
      end
    end

    context 'when the work order already has an input set' do
      let(:set_uuid) { set.uuid }
      it 'should produce an error' do
        expect(data[:error]).to eq("This work order already has an input set.")
      end
    end

    context 'when the work order has no original set' do
      let(:original_set_uuid) { nil }
      it 'should produce an error' do
        expect(data[:error]).to eq("This work order has no original set selected.")
      end
    end

    context 'when the new set cannot be created' do
      def setup
        allow_any_instance_of(WorkOrderDecorator).to receive(:create_editable_set).and_raise("Kaboom")
      end
      it 'should produce an error' do
        expect(data[:error]).to eq("The new set could not be created.")
      end
    end

    context 'when the new set is created' do
      let(:new_set) do
        uuid = SecureRandom.uuid
        double(:set, name: 'New set', id: uuid, uuid: uuid)
      end

      def setup
        allow_any_instance_of(WorkOrderDecorator).to receive(:create_editable_set).and_return(new_set)
      end

      it 'should not produce an error' do
        expect(data[:error]).to be_nil
      end
      it 'should return the new set information' do
        expect(data[:view_set_url]).to include(new_set.uuid)
        expect(data[:new_set_name]).to eq(new_set.name)
      end
    end

  end

end
