class ProductsController < ApplicationController
  before_action :set_work_plan
  before_action :set_product

  def show_product_inside_work_plan
    authorize! :read, @work_plan

    cost_code = @work_plan.project.cost_code
    price = BillingFacadeClient.get_unit_price(cost_code, @product.name)

    processes = @product.processes.map do |process|
      { name: process.name, id: process.id, links: process.build_available_links, path: selected_modules(process) }
    end

    render json: @product.as_json.merge(
      unit_price: price, cost_code: cost_code, product_processes: processes
    ).to_json
  end

private

  # Returns the selected modules if such things exist; otherwise the default path modules
  def selected_modules(process)
    if @work_plan.product_id==@product.id
      order = @work_plan.work_orders.where(process_id: process.id).first
      if order
        return order.selected_path
      end
    end
    process.build_default_path
  end

  def set_work_plan
    @work_plan = WorkPlan.find(params[:id])
  end

  def set_product
    @product = Product.find(params[:product_id])
  end

end
