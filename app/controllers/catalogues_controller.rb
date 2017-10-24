class CataloguesController < ApplicationController
  skip_authorization_check only: :create
  skip_credentials

  before_action :validate_catalogue, only: [:create]

  # Currently using flimsy service to populate catalogue of products
  # Will not implement SSO just yet...
  # skip_authenticate_user

  def create
    Catalogue.create_with_products(catalogue_params)
    head :created
  end

  private

    def validate_catalogue
      invalid_product_names = BillingFacadeClient.filter_invalid_product_names(catalogue_params[:products].map{|p| p[:name]})
      unless invalid_product_names.length == 0
        render status: 422, json: {errors: [message: "The Billing services does not validate the following products: #{invalid_product_names}"]}
      end
    end

    def catalogue_params
      params.require(:catalogue).permit(:url, :lims_id, :pipeline, products: [:name, :product_version,
                  :product_uuid, :TAT,
                  :description, :requested_biomaterial_type, :availability, :catalogue_id, :product_class])
    end
end
