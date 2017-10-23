class ProductsController < ApplicationController
  def show_product_inside_work_order
    @work_order = WorkOrder.find(params[:id])
    authorize! :read, @work_order
    
    @product = Product.find(params[:product_id])
    cost_code = @work_order.proposal.cost_code
    price = BillingFacadeClient.get_unit_price(cost_code, @product.name)

    render json: @product.as_json.merge(unit_price: price, cost_code: cost_code).to_json
  end

end
