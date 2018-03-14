# Class to handle updating a work order during the work order wizard.
require 'billing_facade_client'
require 'set'

class UpdatePlanService

  def initialize(work_plan_params, work_plan, dispatch, messages)
    @work_plan_params = work_plan_params
    @work_plan = work_plan
    @dispatch = dispatch
    @messages = messages
  end

  # This updates a work order during the work order wizard.
  # Returns true if successful; false if fails.
  # Check messages for an error or notice message.
  def perform
    return false unless check_any_update
    return false unless ready_for_step
    return false if block_set_change

    dispatch_order_id = nil

    if @dispatch
      dispatch_order_id = @work_plan_params[:work_order_id]
      return false unless check_dispatch(dispatch_order_id)
    end

    product_options = nil

    # Requesting to set the modules for all orders in the plan
    if @work_plan_params[:product_options] && @work_plan_params[:product_id]
      product_options = JSON.parse(@work_plan_params[:product_options])
      product = Product.find(@work_plan_params[:product_id])
      return false unless validate_modules(product_options.flatten)
      return false unless check_product_module_ids(product_options, product)
      @work_plan_params = @work_plan_params.except(:product_options)
    elsif @work_plan_params[:product_options] || @work_plan_params[:product_id]
      add_error("Invalid parameters")
      return false
    end

    if @work_plan_params[:project_id]
      return false unless validate_cost_code(@work_plan_params[:project_id])
    end

    update_order = nil

    # Requesting to update the modules in one order
    if @work_plan_params[:work_order_id] && @work_plan_params[:work_order_modules]
      module_ids = JSON.parse(@work_plan_params[:work_order_modules])
      update_order = {
        order_id: @work_plan_params[:work_order_id],
        modules: module_ids,
      }
      return false unless validate_modules(module_ids)
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

    elsif @work_plan_params[:work_order_id] || @work_plan_params[:work_order_modules]
      add_error("Invalid parameters")
      return false
    end

    if @work_plan.update_attributes(@work_plan_params)
      locked_set_uuid = nil

      if (@work_plan_params[:product_id] || product_options) && !@work_plan.work_orders.empty?
        # User is changing their product or options - delete the incorrect work orders
        locked_set_uuid = @work_plan.work_orders.first.set_uuid
        work_order_ids = @work_plan.work_orders.map(&:id)
        WorkOrderModuleChoice.where(work_order_id: work_order_ids).each(&:destroy)
        @work_plan.work_orders.destroy_all
      end

      if update_order
        WorkOrderModuleChoice.where(work_order_id: update_order[:order_id]).each(&:destroy)
        update_order[:modules].each_with_index do |mid, i|
          WorkOrderModuleChoice.create!(work_order_id: update_order[:order_id], aker_process_modules_id: mid, position: i)
        end
      end

      if product_options && @work_plan.work_orders.empty?
        begin
          @work_plan.create_orders(product_options, locked_set_uuid)
        rescue => e
          Rails.logger.error("Failed to create work orders")
          Rails.logger.error e
          Rails.logger.error e.backtrace
          add_error("Creating the work orders failed")
          return false
        end
      end

      if dispatch_order_id
        return false unless send_order(dispatch_order_id)
        generate_submitted_event(dispatch_order_id)
      end
    end

    return true
  end

private

  def ready_for_step
    unless @work_plan.original_set_uuid
      if [:project_id, :product_id, :product_options, :comment, :desired_date, :order_id, :work_order_modules].any? { |field| @work_plan_params[field] }
        add_error("Please select a set in an earlier step.")
        return false
      end
    end
    unless @work_plan.project_id
      if [:product_id, :product_options, :comment, :desired_date, :order_id, :work_order_modules].any? { |field| @work_plan_params[field] }
        add_error("Please select a project in an earlier step.")
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

  # It is an error for the user to try to repick the set after the locked clone has been created
  def block_set_change
    if @work_plan_params[:original_set_uuid] && !@work_plan.work_orders.empty? &&
          @work_plan.work_orders.first.set_uuid &&
          @work_plan.work_orders.first.original_set_uuid!=@work_plan_params[:original_set_uuid]
        Rails.logger.error "User tried to re-select set after locked set had been created."
        add_error("The starting set for this work plan has already been locked. " +
              "To order work for different samples, please start a new work plan.")
      return true
    end
  end

  # Don't let the user change plan-level details about a plan that has already been partially dispatched
  def check_any_update
    return true if @work_plan.in_construction?
    unless @work_plan.active?
      add_error("This work plan cannot be updated.")
      return false
    end
    if [:original_set_uuid, :project_id, :product_id, :product_options, :comment, :desired_date].any? { |field| @work_plan_params[field] }
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
    unless order.original_set_uuid
      previous_order = orders.reverse.find(&:closed?)
      order.update_attributes!(original_set_uuid: previous_order.finished_set_uuid)
    end

    return false unless check_set_contents(order.original_set_uuid)

    if order.original_set.locked
      order.update_attributes!(set_uuid: order.original_set_uuid)
    else
      order.create_locked_set
      return false unless check_set_contents(order.set_uuid)
    end
    return true
  end

  def check_set_contents(set_uuid)
    begin
      mids = SetClient::Set.find_with_materials(set_uuid).first.materials.map{|m| m.id}
      if mids.empty?
        add_error("The selected set is empty.")
        return false
      end
      materials = all_results(MatconClient::Material.where("_id" => {"$in" => mids}).result_set)
      return true if materials.all? { |mat| mat.attributes['available'] }
      add_error("Some of the materials in the selected set are not available.")
    rescue => e
      Rails.logger.error e
      Rails.logger.error e.backtrace
      add_error("The materials could not be retrieved.")
    end
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

  def validate_cost_code(project_id)
    node = StudyClient::Node.find(project_id).first
    unless node
      add_error("No project could be found with id #{project_id}")
      return false
    end
    
    cost_code = node.cost_code
    unless cost_code
      add_error("The selected project does not have a cost code.")
      return false
    end

    unless BillingFacadeClient.validate_cost_code?(cost_code)
      add_error("The Billing service does not validate the cost code for the selected project.")
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
    order = WorkOrder.find(order_id)
    begin
      order.send_to_lims
    rescue => e
      Rails.logger.error "Failed to send work order"
      Rails.logger.error e
      Rails.logger.error e.backtrace
      add_error("The request to the LIMS failed.")
      return false
    end
    order.update_attributes!(status: 'active', dispatch_date: Date.today)
    return true
  end

   def generate_submitted_event(order_id)
    begin
      order = WorkOrder.find(order_id)
      order.generate_submitted_event
    rescue => e
      # Currently have to restart the server if there is an exception here
      exception_string = e.backtrace.join("\n")
      WorkOrderMailer.message_queue_error(@work_order, exception_string).deliver_later
    end
  end

  def validate_modules(module_ids)
    cost_code = @work_plan.project.cost_code
    module_names = module_ids.map { |id| Aker::ProcessModule.find(id).name }
    bad_modules = module_names.uniq.select { |name| BillingFacadeClient.get_cost_information_for_module(name, cost_code).nil? }
    unless bad_modules.empty?
      add_error "The following modules are not valid for cost code #{cost_code}: #{bad_modules}"
      return false
    end
    true
  end

  def add_error(message)
    @messages[:error] = message
  end

  def add_notice(message)
    @messages[:notice] = message
  end

end
