require 'set'

# This service handles updates to the plan during the wizard's execution.
# It does not handle dispatches.
# It does not handle amending process options.
# It may update the work plan's estimated cost.
class PlanUpdateService
  attr_reader :plan
  attr_reader :params

  def initialize(params, work_plan, user_and_groups, messages)
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

      return false unless check_product_options(product, @product_options, selected_values)

      @selected_values = @product_options.map do |list|
        list.map do |module_id|
          params[:work_order_modules]&.[](module_id.to_s)&.[](:selected_value)
        end
      end
      
      @params = @params.except(:product_options)
    end

    if params[:project_id]
      return false unless validate_project_selection(params[:project_id])
    end

    if params[:data_release_strategy_id]
      return false unless validate_data_release_strategy_selection(params[:data_release_strategy_id])
    end

    # We will need to recalculate the cost if:
    #  - we are changing the project
    #  - we are changing the product or modules
    @update_cost_estimate = (params[:project_id] || @product_options)

    if @update_cost_estimate
      return false unless predict_plan_cost(product_options)
    end

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
  end

  def check_set_change
    set_uuid = params[:original_set_uuid]
    return unless set_uuid
    return error("The set cannot be changed now.") unless plan.work_orders.empty?
    check_set_contents(set_uuid)
  end

  def check_set_contents(set_uuid)
    mids = set_material_ids(set_uuid)
    return error("The selected set is empty.") if mids.empty?
    materials = all_results(MatconClient::Material.where("_id" => {"$in" => mids}).result_set)
    if !materials.all? { |mat| mat.attributes['available'] }
      return error("Some of the materials in the selected set are not available.")
    end
    check_material_permissions(materials.map(&:id))
  rescue => e
    Rails.logger.error e
    Rails.logger.error e.backtrace
    return error("The materials could not be retrieved.")
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

  # -- PRODUCT OPTION CHECKS

  # Each entry in product_options is a list of the modules for a process
  # Each entry in selected_values is a list of the values for those modules
  def check_product_options(product, product_options, selected_values)
    processes = product.processes
    if processes.length != product_options.length || processes.length != selected_values.length
      return error("The modules specified do not match the selected product.")
    end
    processes.zip(product_options, selected_values).all? do |pro, mids, values|
      if modules_ok_for_process(mids, process) && module_values_ok(mids, values)
        true
      else
        error("The given options are not a valid sequence for process \"#{process.name}\".")
      end
    end
  end

  def modules_ok_for_process(module_ids, process)
    pairs = Set.new(Aker::ProcessModulePairings.where(aker_process: process).map { |p| [p.from_step_id, p.to_step_id] })
    last = nil
    module_ids.each do |mid|
      return false unless pairs.include? [last, mid]
      last = mid
    end
    return pairs.include? [last, nil]
  end

  def module_values_ok(module_ids, values)
    module_ids.length == values.length &&
      module_ids.zip(values).all? { |mid, value| Aker::ProcessModule.find(mid).accepts_value(value) }
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
  end

  # -- PROJECT CHECKS

  def check_project_error(project_id)
    return "No project selected." unless project_id
    node = StudyClient::Node.find(project_id).first
    return "No project could be found with id #{project_id}" unless node
    return "The selected project has no parent project." unless node.parent_id
    parent_node = StudyClient::Node.find(node.parent_id).first
    return "The parent of the selected node could not be loaded." unless parent_node
    return "The parent of the selected node has no cost code." unless parent_node.cost_code
    nil
  end

  def validate_project_selection(project_id)
    error = check_project_error(project_id)
    if error
      return error(error)
    end

    begin
      StudyClient::Node.authorize! :spend, project_id, @user_and_groups
      return true
    rescue AkerPermissionGem::NotAuthorized => e
      return error(e.message)
    end
  end


  def predict_plan_cost(product_options)
    @plan_unit_price = nil
    project_id = params[:project_id] || plan.project_id
    return true unless project_id # nothing to check if there is no project id

    cost_code = parent_cost_code(project_id)
    return error("No parent cost code could be found for the selected project.") unless cost_code

    if product_options
      module_names = product_options.flatten.map { |mid| Aker::ProcessModule.find(mid).name }
    else
      module_names = plan.reload.process_module_choices.map { |choice| choice.process_module.name }
    end

    return true if module_names.empty?

    module_costs = UbwClient::get_unit_prices(module_names, cost_code)

    uncosted = module_names - module_costs.keys

    unless uncosted.empty?
      add_error("The following module#{uncosted.size==1 ? ' has' : 's have'} " +
                "no listed price for cost code #{cost_code}: #{uncosted.to_a}")
    end

    @plan_unit_price = module_names.sum { |modname| module_costs[modname] }

    return true
  end

  def update_plan_cost
    return true unless @plan_unit_price && plan.original_set_uuid
    set_size = plan.decorate.original_set.meta[:size]
    plan.update_attributes!(estimated_cost: @plan_unit_price * set_size)
    return true
  end


  def validate_data_release_strategy_selection(data_release_strategy_id)
    return true unless plan.is_product_from_sequencescape?
    return error("Please select a data release strategy in an earlier step.") unless data_release_strategy_id.present?
    return error("The supplied data release strategy id is not UUID.") unless UUID.validate(data_release_strategy_id)

    strategy = DataReleaseStrategyClient.find_strategy_by_uuid(data_release_strategy_id)

    return error("No data release strategy could be found with uuid #{data_release_strategy_id}.") unless strategy

    begin
      unless DataReleaseStrategyClient.find_strategies_by_user(plan.owner_email).any? { |strategy| strategy.id==data_release_strategy_id }
        return error('The owner of this plan cannot select the data release strategy provided.')
      end
    rescue Faraday::ConnectionFailed => e
      return error("There is no connection with the data release service. Please contact the administrator.")
    end

    return true
  end

private

  def parent_cost_code(selected_project_id)
    return nil unless selected_project_id
    parent_id = StudyClient::Node.find(selected_project_id).first&.parent_id
    return nil unless parent_id
    return StudyClient::Node.find(parent_id).first&.cost_code
  end

  def all_results(result_set)
    results = result_set.to_a
    while result_set.has_next? do
      result_set = result_set.next
      results += result_set.to_a
    end
    results
  end

  def set_material_ids(set_uuid)
    SetClient::Set.find_with_materials(set_uuid).first.materials.map(&:id)
  end

  def error(message)
    @messages[:error] = message
    false
  end

end
