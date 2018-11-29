require 'set'

# Some common helper methods from the various plan-related services
class PlanHelper
  attr_reader :plan

  def initialize(plan, user_and_groups, messages)
    @plan = plan
    @messages = messages
    @user_and_groups = user_and_groups
  end

  def validate_data_release_strategy_selection(data_release_strategy_id)
    return true unless plan.is_product_from_sequencescape?
    return error("No data release strategy is selected.") unless data_release_strategy_id.present?

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

  def validate_project_selection(project_id)
    return error("No project id supplied.") unless project_id.present?
    unless parent_cost_code[project_id]
      @messages[:error] ||= "No parent cost code could be identified for the supplied project id."
      return false
    end
    return authorize_project(project_id)
  end

  def authorize_project(project_id)
    StudyClient::Node.authorize! :spend, project_id, @user_and_groups
    return true
  rescue AkerPermissionGem::NotAuthorized => e
    return error(e.message)
  end

  def all_results(result_set)
    results = result_set.to_a
    while result_set.has_next? do
      result_set = result_set.next
      results += result_set.to_a
    end
    results
  end

  def load_materials(matids)
    all_results(MatconClient::Material.where("_id" => {"$in" => matids}).result_set)
  end

  def set_material_ids(set_uuid)
    @set_materials ||= {}
    @set_materials[set_uuid] ||= SetClient::Set.find_with_materials(set_uuid).first.materials.map(&:id)
  end

  # Gets the parent cost code for the given subproject id.
  # Returns nil and adds an error to messages if the cost code cannot be found.
  def parent_cost_code(project_id)
    node = get_node(project_id)
    unless node
      error("No project could be found with id #{project_id}.")
      return nil
    end
    unless node.parent_id
      error("The selected project has no parent project.")
      return nil
    end
    parent_node = get_node(node.parent_id)
    unless parent_node
      error("The parent of the selected node could not be loaded.")
      return nil
    end
    unless parent_node.cost_code
      error("The parent of the selected node has no cost code.")
      return nil
    end
    parent_node.cost_code
  end


  def check_set_contents(set_uuid)
    matids = set_material_ids(set_uuid)
    @set_size = matids.size
    if matids.empty?
      return error("The selected set is empty.")
    end
    materials = load_materials(matids)
    unless materials.all? { |mat| mat.attributes['available'] }
      return error("Some of the selected materials are not available.")
    end
    return check_material_permissions(materials.map(&:id))
  rescue => e
    Rails.logger.error e
    Rails.logger.error e.backtrace
    return error("The materials could not be retrieved.")
  end

  def check_material_permissions(matids)
    return true if StampClient::Permission.check_catch({
      permission_type: :consume,
      names: @user_and_groups,
      material_uuids: matids,
    })

    bad_uuids = StampClient::Permission.unpermitted_uuids
    if bad_uuids.length > 10
      joined = bad_uuids[0,10].to_s +' (too many to list)'
    else
      joined = bad_uuids.to_s
    end
    add_error("Not authorised to consume materials #{joined}.")
    return false
  end

  def predict_unit_price(project_id, module_names)
    cost_code = parent_cost_code(project_id)
    return nil unless cost_code.present?

    if module_names.empty?
      error("No modules specified.")
      return nil
    end

    module_costs = UbwClient::get_unit_prices(module_names, cost_code)

    uncosted = module_names - module_costs.keys

    unless uncosted.empty?
      error("The following module#{uncosted.size==1 ? ' has' : 's have'} " +
                "no listed price for cost code #{cost_code}: #{uncosted.to_a}")
    end

    module_names.sum { |modname| module_costs[modname] }
  end

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

  def get_node(node_id)
    return nil unless node_id
    @nodes ||= {}
    @nodes[node_id] ||= StudyClient::Node.find(selected_project_id).first
  end

  def check_broker
    return true if BrokerHandle.working? || BrokerHandle.events_disabled?
    return error("Could not connect to message exchange.")
  end

  def error(message)
    messages[:error] = message
    false
  end

end