require 'rails_helper'

RSpec.describe CataloguesController, type: :controller do

  describe "#create" do

    let (:catalogue) { double("Catalogue") }
    let (:user) { create(:user) }

    let (:headers) do
      { "Content-Type" => "application/json" }
    end

    context "when posting to /catalogue" do
      it "calls create_with_products method in the model" do
        @request.env['devise.mapping'] = Devise.mappings[:user]
        sign_in user
        expect(Catalogue).to receive(:create_with_products)

        post :create, params: { catalogue: {lims_id: 'a', pipeline: 'b', url: 'c', products: [] } }, headers: headers
        expect(response).to have_http_status(:created)
      end
    end

  end
end
