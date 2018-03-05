class ProductsController < ApplicationController
  before_action :set_work_plan
  before_action :set_product

  def show_product_inside_work_plan
    authorize! :read, @work_plan

    cost_code = @work_plan.project.cost_code
    price = BillingFacadeClient.get_unit_price(cost_code, @product.name)

    # Currently assuming there is only one process to one product
    process = @product.processes[0]
    process_module_pairings = Aker::ProcessModulePairings.where(aker_process_id: process.id)

    available_links = @product.build_available_links(process_module_pairings)
    default_path = @product.build_default_path(process_module_pairings)

    render json: @product.as_json.merge(
      unit_price: price, cost_code: cost_code, available_links: available_links, default_path: default_path
    ).to_json

  end

  private

  def set_work_plan
    @work_plan = WorkPlan.find(params[:id])
  end

  def set_product
    @product = Product.find(params[:product_id])
  end

end
