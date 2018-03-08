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
      default_path = process.build_default_path

      process_info[:name] = process.name
      process_info[:id] = process.id
      process_info[:available_links] = available_links
      process_info[:default_path] = default_path

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
