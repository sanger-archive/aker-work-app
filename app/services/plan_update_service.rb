require 'set'
require 'uuid'

# This service handles updates to the plan during the wizard's execution.
# It does not handle dispatches.
# It does not handle amending process options.
# It may update the work plan's estimated cost.
class PlanUpdateService
  attr_reader :plan
  attr_reader :params

  def initialize(params, plan, user_and_groups, messages)
    @params = params
    @plan = plan
    @user_and_groups = user_and_groups.flatten
    @messages = messages
  end

  def checks
    return false unless check_any_update
    return false unless check_ready_for_step
    return false unless check_set_change

    @product_options = nil
    if params[:product_options].present? || params[:product_id].present?
      unless params[:product_options].present? && params[:product_id].present?
        return error("Please select product and options to proceed.")
      end

      @product = Product.find(params[:product_id])
      @product_options = JSON.parse(params[:product_options])

      return false unless helper.check_product_options(product, @product_options, selected_values)

      @selected_values = @product_options.map do |list|
        list.map do |module_id|
          params[:work_order_modules]&.[](module_id.to_s)&.[](:selected_value)
        end
      end
      
      @params = @params.except(:product_options)
    end

    if params[:project_id]
      return false unless helper.validate_project_selection(params[:project_id])
    end

    if params[:data_release_strategy_id]
      return false unless helper.validate_data_release_strategy_selection(params[:data_release_strategy_id])
    end

    # We will need to recalculate the cost if:
    #  - we are changing the project
    #  - we are changing the product or modules
    @update_cost_estimate = (params[:project_id] || @product_options)

    if @update_cost_estimate
      return false unless predict_plan_cost(product_options)
    end

    return true

  end

  def perform
    return false unless checks

    plan.update_attributes!(params)

    if @product_options
      choose_modules(@product, @product_options, @selected_values)
    end

    if @update_cost_estimate
      return false unless update_plan_cost
    end

    return true
  end

  # Don't let the user change plan-level details about a plan that has already been partially dispatched
  def check_any_update
    return true if plan.in_construction?
    return error("This work plan cannot be updated.")
  end

  def check_ready_for_step
    unless plan.original_set_uuid
      if [:project_id, :product_id, :product_options, :comment, :priority, :order_id, :work_order_modules, :data_release_strategy_id ].any? { |field| params[field] }
        return error("Please select a set in an earlier step.")
      end
    end
    unless plan.project_id
      if [:product_id, :product_options, :comment, :priority, :order_id, :work_order_modules, :data_release_strategy_id].any? { |field| params[field] }
        return error("Please select a project in an earlier step.")
      end
    end
    unless plan.product_id
      if params[:data_release_strategy_id]
        return error("Please select a product in an earlier step.")
      end
    end
    return true
  end

  def check_set_change
    set_uuid = params[:original_set_uuid]
    return true unless set_uuid
    return error("The set cannot be changed now.") unless plan.work_orders.empty?
    helper.check_set_contents(set_uuid)
  end

  def check_material_permissions(mids)
    return true if StampClient::Permission.check_catch({
      permission_type: :consume,
      names: @user_and_groups,
      material_uuids: mids,
    })

    bad_uuids = StampClient::Permission.unpermitted_uuids
    if bad_uuids.length > 10
      joined = bad_uuids[0,10].to_s + ' (too many to list)'
    else
      joined = bad_uuids.to_s
    end
    return error("Not authorised to consume materials #{joined}.")
  end

  # Choosing product options for the whole plan
  def choose_modules(product, module_ids, selected_values)
    wp = plan
    product.processes.zip(module_ids, selected_values).each do |pro,modids,vals|
      create_module_choices(wp, pro, modids, vals)
    end
  end

  def create_module_choices(plan, process, module_ids, selected_values)
    module_ids.zip(selected_values).each_with_index do |modid,val,pos|
      ProcessModuleChoice.create!(work_plan: plan, aker_process: process,
        aker_process_module_id: modid, selected_value: val, position: pos)
    end
  end

  def predict_plan_cost(product_options)
    @plan_unit_price = nil
    project_id = params[:project_id] || plan.project_id
    return true unless project_id # nothing to check if there is no project id

    if product_options
      module_names = product_options.flatten.map { |mid| Aker::ProcessModule.find(mid).name }
    else
      module_names = plan.reload.process_module_choices.map { |choice| choice.process_module.name }
    end

    return true if module_names.empty?

    @plan_unit_price = helper.predict_unit_price(project_id, module_names)

    return @plan_unit_price.present?
  end

  def update_plan_cost
    return true unless @plan_unit_price && plan.original_set_uuid
    set_size = plan.decorate.original_set.meta[:size]
    plan.update_attributes!(estimated_cost: @plan_unit_price * set_size)
    return true
  end

private

  def helper
    @helper ||= PlanHelper.new(@plan, @user_and_groups, @messages)
  end

  def error(message)
    @messages[:error] = message
    false
  end

end
