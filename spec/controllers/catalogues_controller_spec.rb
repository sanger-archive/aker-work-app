require 'rails_helper'
require 'ostruct'

RSpec.describe CataloguesController, type: :controller do

  describe "#create" do

    let (:catalogue) { double("Catalogue") }
    let (:user) { OpenStruct.new(email: 'jeff', groups: ['world']) }

    let (:headers) do
      { "Content-Type" => "application/json" }
    end

    context "when posting to /catalogue" do
      it "calls create_with_products method in the model" do
        if user
          allow_any_instance_of(CataloguesController).to receive(:check_credentials)
          allow_any_instance_of(CataloguesController).to receive(:current_user)
        end
        expect(Catalogue).to receive(:create_with_products)

        post :create, params: { catalogue: {lims_id: 'a', pipeline: 'b', url: 'c', products: [] } }, headers: headers
        expect(response).to have_http_status(:created)
      end
    end

  end
end
