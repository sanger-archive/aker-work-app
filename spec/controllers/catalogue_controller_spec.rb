require 'rails_helper'

RSpec.describe CataloguesController, type: :controller do

	describe "#create" do

		let (:catalogue) { double("Catalogue") }

	    context "when posting to /catalogue" do
	   		it "calls create_with_products method in the model" do
				expect(Catalogue).to receive(:create_with_products)
				headers = {
			      "Content-Type" => "application/json",     # This is what Rails 4 accepts
			    }
				post :create, params: { catalogue: {lims_id: 'a', pipeline: 'b', url: 'c', products: [] } }, headers: headers
				expect(response).to have_http_status(:created)
	   		end

	   	end

	end
end