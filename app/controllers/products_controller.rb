class ProductsController < ApplicationController
  before_action :work_plan
  before_action :set_product, only: [:show_product_inside_work_plan]

  def show_product_inside_work_plan
    authorize! :read, work_plan

    cost_code = work_plan.decorate.project.cost_code
    parent_cost_code = work_plan.decorate.parent_cost_code

    module_names = @product.processes.flat_map(&:process_modules).map(&:name).uniq
    unit_prices = UbwClient::get_unit_prices_or_nil(module_names, parent_cost_code) || {}

    processes = @product.processes.map do |process|
      {
        name: process.name, id: process.id, tat: process.TAT,
        process_class: process.process_class_human,
        links: process.build_available_links(unit_prices),
        path: selected_modules(process, unit_prices),
      }
    end

    total_tat = @product.processes.map { |pro| pro.TAT }.inject(0, :+)

    render json: @product.as_json.merge(
      cost_code: cost_code, product_processes: processes, total_tat: total_tat
    ).to_json
  end

  def modules_unit_price
    authorize! :read, work_plan
    parent_cost_code = work_plan.decorate.parent_cost_code
    unit_price = nil
    errors = []
    if !parent_cost_code
      errors.push("There is no cost code associated with this order's project.")
    else
      module_names = params[:module_ids].split('-').map { |id| Aker::ProcessModule.find(id).name }
      unit_prices = UbwClient::get_unit_prices_or_nil(module_names, parent_cost_code)
      if unit_prices.nil?
        errors.push("There was a problem retrieving information from UBW.")
      else
        bad_modules = module_names.select { |name| unit_prices[name].nil? }
        if bad_modules.any?
          errors.push("The following modules are not valid for cost code #{parent_cost_code}: #{bad_modules}")
        else
          unit_price = unit_prices.values.inject(0, :+)
        end
      end
    end

    render json: {errors: errors, unit_price: unit_price}.to_json
  end

private

  # Returns the selected modules if such things exist; otherwise the default path modules
  def selected_modules(process, unit_prices)
    selected_modules = process.selected_path(work_plan)
    selected_modules = process.build_default_path(unit_prices) if selected_modules.empty?
    selected_modules
  end

  def work_plan
    @work_plan = WorkPlan.find(params[:id])
  end

  def set_product
    @product = Product.find(params[:product_id])
  end

end
