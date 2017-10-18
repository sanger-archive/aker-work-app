require 'rails_helper'
require 'ostruct'

RSpec.describe CataloguesController, type: :controller do

  describe "#create" do

    let (:catalogue) { double("Catalogue") }
    let (:user) { OpenStruct.new(email: 'jeff', groups: ['world']) }

    let (:headers) do
      { "Content-Type" => "application/json" }
    end

    let(:BillingFacadeClient) { double('facade') }
    

    context "when posting to /catalogue" do
      it "calls create_with_products method in the model" do
        allow(BillingFacadeClient).to receive(:filter_invalid_product_names).and_return([])

        if user
          allow_any_instance_of(CataloguesController).to receive(:check_credentials)
          allow_any_instance_of(CataloguesController).to receive(:current_user)
        end
        expect(Catalogue).to receive(:create_with_products)

        post :create, params: { catalogue: {lims_id: 'a', pipeline: 'b', url: 'c', products: [{name: 'a name'}] } }, headers: headers
        expect(response).to have_http_status(:created)
      end

      context 'when validating a catalogue' do
        
        let(:products) {[{name: 'name1'}, {name: 'another'}]}
        let(:product_names) { products.map{|p| p[:name]} }
        let(:catalogue) { { catalogue: {lims_id: 'a', pipeline: 'b', url: 'c', products: products } } } 


        context 'when the billing service is running' do
          it 'uses the billing facade to validate it' do
            expect(BillingFacadeClient).to receive(:filter_invalid_product_names).with(product_names).and_return([])
            post :create, params: catalogue, headers: headers
          end

          context 'when the product names of the catalogue are valid' do
            setup do
              allow(BillingFacadeClient).to receive(:filter_invalid_product_names).and_return([])
            end
            it 'returns a created response' do
              post :create, params: catalogue, headers: headers
              expect(response).to have_http_status(:created)
            end
          end
          context 'when the product names are not valid' do
            setup do
              allow(BillingFacadeClient).to receive(:filter_invalid_product_names).and_return([product_names.first])
            end

            it 'returns a 422' do
              post :create, params: catalogue, headers: headers
              expect(response).to have_http_status(422)
            end

            it 'returns the list of errored product names' do
              post :create, params: catalogue, headers: headers
              expect(response.body.include?(product_names.first)).to eq(true)
            end
          end
        end
      end

      
    end

  end
end
