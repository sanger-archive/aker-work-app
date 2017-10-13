class ProductsController < ApplicationController
  skip_authorization_check only: :show
  skip_credentials

  def show
    @product = Product.find(params[:id])
    render json: @product
  end
end
