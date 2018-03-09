class ProductsController < ApplicationController
  before_action :set_work_plan
  before_action :set_product

  def show_product_inside_work_plan
    authorize! :read, @work_plan

    cost_code = @work_plan.project.cost_code
    price = BillingFacadeClient.get_unit_price(cost_code, @product.name)

    processes = []

    @product.processes.each do |process|
      process_info = {}

      available_links = process.build_available_links
      path = process.build_default_path

      # Replace the default path by the plan's currently selected module path, if such a thing exists
      if @work_plan.product_id==@product.id
        order = @work_plan.work_orders.where(process_id: process.id).first
        if order
          path = order.selected_path
        end
      end

      process_info[:name] = process.name
      process_info[:id] = process.id
      process_info[:links] = available_links
      process_info[:path] = path

      processes.push(process_info)
    end

    render json: @product.as_json.merge(
      unit_price: price, cost_code: cost_code, product_processes: processes
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
