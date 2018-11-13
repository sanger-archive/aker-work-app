# Class to handle updating a work order during the work order wizard.
require 'set'
require 'broker'
require 'uuid'
require 'bigdecimal'

class UpdatePlanService

  def initialize(work_plan_params, work_plan, dispatch, user_and_groups, messages)
    @work_plan_params = work_plan_params
    @work_plan = work_plan
    @dispatch = dispatch
    @user_and_groups = user_and_groups.flatten
    @messages = messages
  end

  # This updates a work order during the work order wizard.
  # Returns true if successful; false if fails.
  # Check messages for an error or notice message.
  def perform
    return false unless check_any_update
    return false unless ready_for_step
    return false unless check_set_change

    dispatch_order_id = nil

    if @dispatch
      return false unless check_broker
      dispatch_order_id = @work_plan_params[:work_order_id]
      return false unless check_dispatch(dispatch_order_id)
    end

    product_options = nil
    # Requesting to set the modules for all orders in the plan
    if @work_plan_params[:product_options].present? && @work_plan_params[:product_id].present?
      product_options = JSON.parse(@work_plan_params[:product_options])
      product_options_selected_values = product_options.map do |list|
        list.map do |module_id|
          if @work_plan_params[:work_order_module] && @work_plan_params[:work_order_module][module_id.to_s]
            @work_plan_params[:work_order_module][module_id.to_s][:selected_value]
          end
        end
      end
      product = Product.find(@work_plan_params[:product_id])
      #return false unless validate_modules(product_options.flatten)
      return false unless check_product_module_ids(product_options, product)
      @work_plan_params = @work_plan_params.except(:product_options)
    elsif @work_plan_params[:product_options] || @work_plan_params[:product_id]
      add_error("Please select an option to proceed")
      return false
    end

    if @work_plan_params[:project_id]
      return false unless validate_project_selection(@work_plan_params[:project_id])
    end

    if @work_plan_params[:data_release_strategy_id]
      return false unless validate_data_release_strategy_selection(@work_plan_params[:data_release_strategy_id])
    end

    update_order = nil

    # Requesting to update the modules in one order
    if @work_plan_params[:work_order_id] && @work_plan_params[:work_order_modules]
      module_ids = JSON.parse(@work_plan_params[:work_order_modules])
      modules_selected_values = modules_selected_value_from_module_ids(module_ids)
      update_order = {
        order_id: @work_plan_params[:work_order_id],
        modules: module_ids,
        modules_selected_value: modules_selected_values
      }
      #return false unless validate_modules(module_ids)
      order = WorkOrder.find(update_order[:order_id])
      unless order.work_plan == @work_plan
        add_error("The work order specified is not part of this work plan.")
        return false
      end
      unless order.queued?
        add_error("The work order specified cannot be updated.")
        return false
      end
      return false unless check_process_module_ids(module_ids, order.process)
      @work_plan_params = @work_plan_params.except(:work_order_id, :work_order_modules)
      modules_changed = true
    elsif @work_plan_params[:work_order_id] || @work_plan_params[:work_order_modules]
      add_error("Invalid parameters")
      return false
    end
    # We will need to recalculate the cost if:
    #  - we are changing the project
    #  - we are changing the product
    #  - we are changing the modules for an order
    #  - we are setting the modules for all the orders
    #  - we are dispatching the order
    update_cost_estimate = (@work_plan_params[:project_id] || @work_plan_params[:product_id] ||
                             update_order || product_options || dispatch_order_id)

    # Before we change a bunch of other stuff, check if the module/cost code is going to be valid
    if update_cost_estimate
      return false unless precheck_modules_with_cost_code(update_order, product_options)
    end

    @work_plan_params = @work_plan_params.except(:work_order_module)

    if @work_plan.update_attributes(@work_plan_params)
      locked_set_uuid = nil
      begin
        ActiveRecord::Base.transaction do
          if (@work_plan_params[:product_id] || product_options) && !@work_plan.work_orders.empty?
            # User is changing their product or options - delete the incorrect work orders
            locked_set_uuid = @work_plan.work_orders.first.set_uuid
            work_order_ids = @work_plan.work_orders.map(&:id)
            WorkOrderModuleChoice.where(work_order_id: work_order_ids).each(&:destroy)
            @work_plan.work_orders.each(&:destroy) # use individual destroy to trigger proper cleanup (e.g. permissions)
            if @work_plan.work_orders.respond_to? :reload
              @work_plan.work_orders.reload
            else
              @work_plan.work_orders.object.reload
              @work_plan.work_orders.clear # draper collectiondecorator does not refresh
            end
          end

          if update_order
            WorkOrderModuleChoice.where(work_order_id: update_order[:order_id]).each(&:destroy)
            update_order[:modules].each_with_index do |mid, i|
              WorkOrderModuleChoice.create!(work_order_id: update_order[:order_id], aker_process_modules_id: mid, position: i,
                selected_value: update_order[:modules_selected_value][i].to_i)
            end
          end
        end
      rescue => e
        Rails.logger.error("Failed to update work orders")
        Rails.logger.error e
        Rails.logger.error e.backtrace
        add_error("Update of work orders failed")
        return false
      end

      if product_options && @work_plan.work_orders.empty?
        begin
          @work_plan.create_orders(product_options, locked_set_uuid, product_options_selected_values)
        rescue => e
          Rails.logger.error("Failed to create work orders")
          Rails.logger.error e
          Rails.logger.error e.backtrace
          add_error("Creating the work orders failed")
          return false
        end
      end

      if update_cost_estimate
        return false unless update_cost_quotes
      end

      if dispatch_order_id
        return false unless send_order(dispatch_order_id)
        # Now the order is final, we can send the work order queued events
        unless @work_plan.sent_queued_events
          @work_plan.work_orders.each { |wo| BrokerHandle.publish(WorkOrderEventMessage.new(work_order: wo, status: 'queued')) }
          @work_plan.update_attributes!(sent_queued_events: true)
        end
        generate_dispatched_event(dispatch_order_id)
      end
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

  def precheck_modules_with_cost_code(update_order, product_options)
    project_id = @work_plan_params[:project_id] || @work_plan.project_id
    return true unless project_id # nothing to check if there is no project id
    cost_code = parent_cost_code(project_id)
    unless cost_code
      add_error("No parent cost code could be found for the selected project.")
      return false
    end

    # If present, product_options is array of arrays of module ids to link to the respective orders
    # If present, update_order[:order_id] and update_order[:modules] gives the module ids of one of the orders
    if not product_options
      return true if @work_plan.work_orders.empty?
      module_ids = @work_plan.work_orders.map do |order|
        next unless order.queued?

        if update_order && update_order[:order_id].to_i==order.id
          update_order[:modules]
        else
          order.process_modules.map(&:id)
        end
      end.compact.flatten
    else
      module_ids = product_options.flatten
    end

    modules = Aker::ProcessModule.where(id: module_ids)
    missing_module_ids = Set.new(module_ids) - modules.map(&:id)
    unless missing_module_ids.empty?
      add_error("Invalid module ids: #{missing_module_ids.to_a}")
      return false
    end

    return true if modules.empty?
    module_names = modules.map(&:name)

    uncosted = UbwClient::missing_unit_prices(module_names, cost_code)

    unless uncosted.empty?
      add_error("The following #{uncosted.size==1 ? 'module has' : 'modules have'} " +
                "no listed price for cost code #{cost_code}: #{uncosted.to_a}")
      return false
    end

    return true
  end

  def fetch_set_size(set_uuid)
    return nil unless set_uuid
    @set_size_cache ||= {}
    @set_size_cache[set_uuid] ||= SetClient::Set.find(set_uuid)&.first&.meta&.[](:size)
  end

  def calculate_unit_price(order, cost_code)
    return nil if cost_code.nil?
    module_names = order.process_modules.map(&:name)
    unit_prices = UbwClient::get_unit_prices(module_names, cost_code)
    uncosted = module_names.reject { |name| unit_prices[name].present? }
    unless uncosted.empty?
      add_error("The following module#{uncosted.size==1 ? ' has' : 's have'} " +
                "no listed price for cost code #{cost_code}: #{uncosted.to_a}")
      return nil
    end

    return unit_prices.values.reduce(0, :+)
  end

  def update_cost_quotes
    @work_plan = @work_plan.reload # Doesn't work properly without this line
    return true if @work_plan.work_orders.empty? # Evidently haven't reached the orders part yet, so nothing to do
    cost_code = @work_plan.decorate.parent_cost_code
    unless cost_code
      add_error("No cost code is associated with this work plan.")
      return false
    end

    cur_set_uuid = @work_plan.original_set_uuid
    @work_plan.work_orders.each do |order|
      cur_set_uuid = order.finished_set_uuid || order.set_uuid || order.original_set_uuid || cur_set_uuid
      next unless order.queued?
      num_samples = fetch_set_size(cur_set_uuid)
      if cur_set_uuid && num_samples.nil?
        add_error("Couldn't retrieve number of samples for set #{cur_set_uuid}")
        return false
      end

      cost_per_sample = calculate_unit_price(order, cost_code)
      total_cost = cost_per_sample && cost_per_sample*num_samples
      order.update_attributes!(cost_per_sample: cost_per_sample, total_cost: total_cost)
    end

    true
  end

  def modules_selected_value_from_module_ids(module_ids)
    module_ids.map do |id|
      if @work_plan_params[:work_order_module] && @work_plan_params[:work_order_module][id.to_s]
        @work_plan_params[:work_order_module][id.to_s][:selected_value]
      else
        nil
      end
    end
  end

  def ready_for_step
    unless @work_plan.original_set_uuid
      if [:project_id, :product_id, :product_options, :comment, :priority, :order_id, :work_order_modules, :data_release_strategy_id ].any? { |field| @work_plan_params[field] }
        add_error("Please select a set in an earlier step.")
        return false
      end
    end
    unless @work_plan.project_id
      if [:product_id, :product_options, :comment, :priority, :order_id, :work_order_modules, :data_release_strategy_id].any? { |field| @work_plan_params[field] }
        add_error("Please select a project in an earlier step.")
        return false
      end
    end
    unless @work_plan.product_id
      if [:data_release_strategy_id].any? { |field| @work_plan_params[field] }
        add_error("Please select a product in an earlier step.")
        return false
      end
    end
    if @work_plan.work_orders.empty?
      if [:order_id, :work_order_modules].any? { |field| @work_plan_params[field] }
        add_error("Please specify the product fully in an earlier step.")
        return false
      end
    end
    return true
  end

  def all_results(result_set)
    results = result_set.to_a
    while result_set.has_next? do
      result_set = result_set.next
      results += result_set.to_a
    end
    results
  end

  def check_broker
    return true if BrokerHandle.working? || BrokerHandle.events_disabled?
    add_error("Could not connect to message exchange.")
    return false
  end

  def check_set_change
    set_uuid = @work_plan_params[:original_set_uuid]
    return true if !set_uuid

    # It is an error for the user to try to repick the set after the locked clone has been created
    if !@work_plan.work_orders.empty? &&
          @work_plan.work_orders.first.set_uuid &&
          @work_plan.work_orders.first.original_set_uuid!=set_uuid
        Rails.logger.error "User tried to re-select set after locked set had been created."
        add_error("The starting set for this work plan has already been locked. " +
              "To order work for different samples, please start a new work plan.")
      return false
    end

    # Check the set is usable
    return check_set_contents(set_uuid)
  end

  # Don't let the user change plan-level details about a plan that has already been partially dispatched
  def check_any_update
    return true if @work_plan.in_construction?
    unless @work_plan.active?
      add_error("This work plan cannot be updated.")
      return false
    end
    if [:original_set_uuid, :project_id, :product_id, :product_options, :comment, :priority].any? { |field| @work_plan_params[field] }
      add_error("That change cannot be made because this work plan is in progress.")
      return false
    end
    return true
  end

  def check_dispatch(order_id)
    if @work_plan.work_orders.empty?
      add_error("The orders are not ready for dispatch.")
      return false
    end
    order = WorkOrder.find(order_id)
    if !order || order.work_plan != @work_plan
      add_error("That order is not part of this work plan.")
      return false
    end
    unless order.queued?
      add_error("That order cannot be dispatched.")
      return false
    end
    orders = @work_plan.work_orders
    first_unclosed = orders.find { |o| !o.closed? }
    unless first_unclosed==order
      add_error("That order is not ready to be dispatched.")
      return false
    end

    return false unless authorize_project(@work_plan.project_id)
    return false unless validate_data_release_strategy_selection(@work_plan.data_release_strategy_id)

    unless order.original_set_uuid
      previous_order = orders.reverse.find(&:closed?)
      order.update_attributes!(original_set_uuid: previous_order.finished_set_uuid)
    end

    return false unless check_set_contents(order.set_uuid || order.original_set_uuid)

    if order.decorate.finalise_set
      return false unless check_set_contents(order.set_uuid)
    end
    return true
  end

  def check_set_contents(set_uuid)
    unless set_uuid
      add_error("This work order has no selected set to work with")
      return false
    end

    begin
      mids = SetClient::Set.find_with_materials(set_uuid).first.materials.map{|m| m.id}
      if mids.empty?
        add_error("The selected set is empty.")
        return false
      end
      materials = all_results(MatconClient::Material.where("_id" => {"$in" => mids}).result_set)
      if !materials.all? { |mat| mat.attributes['available'] }
        add_error("Some of the materials in the selected set are not available.")
        return false
      end
      return check_material_permissions(materials.map(&:id))
    rescue => e
      Rails.logger.error e
      Rails.logger.error e.backtrace
      add_error("The materials could not be retrieved.")
      return false
    end
  end

  def check_material_permissions(material_uuids)
    return true if StampClient::Permission.check_catch({
      permission_type: :consume,
      names: @user_and_groups,
      material_uuids: material_uuids,
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

  def modules_ok_for_process(module_ids, process)
    pairs = Set.new(Aker::ProcessModulePairings.where(aker_process: process).map { |p| [p.from_step_id, p.to_step_id] })
    last = nil
    module_ids.each do |mid|
      unless pairs.include? [last, mid]
        return false
      end
      last = mid
    end
    return pairs.include? [last, nil]
  end

  def check_process_module_ids(module_ids, process)
    return true if modules_ok_for_process(module_ids, process)
    add_error("The given modules are not a valid sequence for #{process.name}")
    return false
  end

  def check_product_module_ids(module_id_arrays, product)
    if module_id_arrays.length != product.processes.length
      add_error("The modules specified do not match the selected product.")
      return false
    end
    return module_id_arrays.zip(product.processes).all? { |mids, pro| check_process_module_ids(mids, pro) }
  end

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
      add_error(error)
      return false
    end

    return false unless authorize_project(project_id)

    return true
  end

  def authorize_project(project_id)
    begin
      StudyClient::Node.authorize! :spend, project_id, @user_and_groups
      return true
    rescue AkerPermissionGem::NotAuthorized => e
      add_error(e.message)
      return false
    end
  end

  def validate_data_release_strategy_selection(data_release_strategy_id)
    return true unless @work_plan.is_product_from_sequencescape?

    if data_release_strategy_id.nil?
      add_error("Please select a data release strategy in an earlier step.")
      return false
    end

    strategy = DataReleaseStrategyClient.find_strategy_by_uuid(data_release_strategy_id)

    unless strategy
      add_error("No data release strategy could be found with uuid #{data_release_strategy_id}")
      return false
    end

    unless UUID.validate(data_release_strategy_id)
      add_error('The value for data release strategy selected is not a UUID')
      return false
    end

    value = nil
    begin
      value = DataReleaseStrategyClient.find_strategies_by_user(@work_plan.owner_email).any? do |strategy|
        strategy.id == data_release_strategy_id
      end
    rescue Faraday::ConnectionFailed => e
      value = nil
      add_error('There is no connection with the Data release service. Please contact with the administrator')
      return false
    end

    unless value
      add_error('The current user cannot select the Data release strategy provided.')
      return false
    end
    return true
  end

  def create_work_order_module_choices(product_options)
    work_order_id = @work_plan.id

    # Remove the previously selected options (if any)
    WorkOrderModuleChoice.where(work_order_id: work_order_id).each(&:destroy)

    # Update with the new options
    product_options.each_with_index do |module_id, index|
      WorkOrderModuleChoice.create!(work_order_id: work_order_id, aker_process_modules_id: module_id, position: index)
    end
  end

  def send_order(order_id)
    unless @work_plan.product.available?
      add_notice("That product is suspended and cannot currently be ordered.")
      return false
    end
    work_order = WorkOrder.find(order_id)

    if work_order.jobs.size == 0 && !work_order_splitter.split(work_order)
      add_error("The work order could not be split into jobs.")
      return false
    end

    if work_order_dispatcher.dispatch(work_order)
      return true
    else
      add_error("The request to the LIMS failed")
      Rails.logger.error "Failed to send work order"
      Rails.logger.error work_order_dispatcher.errors.full_messages
      return false
    end
  end

   def generate_dispatched_event(order_id)
    order = WorkOrder.find(order_id)
    order.generate_dispatched_event
  end

  def add_error(message)
    @messages[:error] = message
  end

  def add_notice(message)
    @messages[:notice] = message
  end

  def work_order_dispatcher
    WorkOrderDispatcher.new(serializer: WorkOrderSerializer.new)
  end

  def work_order_splitter
    WorkOrderSplitter::ByContainer.new
  end

end
