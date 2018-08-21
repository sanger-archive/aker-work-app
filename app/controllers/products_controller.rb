class ProductsController < ApplicationController
  before_action :work_plan
  before_action :set_product, only: [:show_product_inside_work_plan]

  def show_product_inside_work_plan
    authorize! :read, work_plan

    cost_code = work_plan.decorate.project.cost_code

    processes = @product.processes.map do |process|
      {
        name: process.name, id: process.id, tat: process.TAT,
        process_class: process.process_class_human,
        links: process.build_available_links,
        path: selected_modules(process)
      }
    end

    total_tat = @product.processes.map { |pro| pro.TAT }.inject(0, :+)

    render json: @product.as_json.merge(
      cost_code: cost_code, product_processes: processes, total_tat: total_tat
    ).to_json
  end

  def modules_unit_price
    authorize! :read, work_plan
    cost_code = work_plan.decorate.project.cost_code
    module_names = params[:module_ids].split('-').map { |id| Aker::ProcessModule.find(id).name }
    unit_prices = module_names.map { |name| [name, BillingFacadeClient.get_cost_information_for_module(name, cost_code)] }
    errors = []
    unit_price = nil
    if unit_prices.any? { |name, cost| cost.nil? }
      bad_modules = unit_prices.select { |name, cost| cost.nil? }.map { |name, cost| name }
      errors.push("The following modules are not valid for cost code #{cost_code}: #{bad_modules}")
    else
      unit_price = unit_prices.map { |name, cost| cost }.inject(0, :+)
    end
    render json: {errors: errors, unit_price: unit_price}.to_json
  end

private

  # Returns the selected modules if such things exist; otherwise the default path modules
  def selected_modules(process)
    if work_plan.product_id==@product.id
      order = @work_plan.work_orders.where(process_id: process.id).first
      if order
        return order.selected_path
      end
    end
    process.build_default_path
  end

  def work_plan
    @work_plan = WorkPlan.find(params[:id])
  end

  def set_product
    @product = Product.find(params[:product_id])
  end

end
