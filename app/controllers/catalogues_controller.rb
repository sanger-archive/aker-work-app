class CataloguesController < ApplicationController
  skip_authorization_check only: :create

	def create
		Catalogue.create_with_products(catalogue_params)
    head :created
	end

	private

	def catalogue_params
		params.require(:catalogue).permit(:url, :lims_id, :pipeline, products: [:name, :product_version, :TAT, :cost_per_sample,
  			        :description, :requested_biomaterial_type, :availability, :catalogue_id])
	end
end
