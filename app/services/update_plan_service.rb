# Class to handle updating a work order during the work order wizard.
require 'billing_facade_client'

class UpdatePlanService

  attr_reader :messages

  def initialize(work_plan_params, work_plan, messages)
    @work_plan_params = work_plan_params
    @work_plan = work_plan
    @messages = messages
  end

  # This updates a work order during the work order wizard.
  # Returns true if successful; false if fails.
  # Check messages for an error or notice message.
  def perform
    product_options = nil
    if @work_plan_params[:product_options]
      product_options = JSON.parse(@work_plan_params[:product_options])
      @work_plan_params.delete(:product_options)
    end

    return false if block_any_update
    return false unless ready_for_step
    return false if block_set_change

    if @work_plan_params[:project_id]
      return false unless validate_cost_code(@work_plan_params[:project_id])
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

      # TODO calculate cost at some point

      # TODO - handle dispatch
    end

    return true
  end

private

  def ready_for_step
    unless @work_plan.original_set_uuid
      if [:project_id, :product_id, :product_options, :comment, :desired_date].any? { |field| @work_plan_params[field] }
        add_error("Please select a set in an earlier step.")
        return false
      end
    end
    unless @work_plan.project_id
      if [:product_id, :product_options, :comment, :desired_date].any? { |field| @work_plan_params[field] }
        add_error("Please select a project in an earlier step.")
        return false
      end
    end
    # TODO - check when they press "dispatch!" button that everything is filled in
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

  def block_any_update
    # TODO - allow some changes for subsequent work orders
    unless @work_plan.in_construction?
      add_error("This work plan has already been issued. Changes are not possible.")
      return true
    end
    return false
  end

  def check_set_contents
    begin
      mids = SetClient::Set.find_with_materials(@work_plan.original_set_uuid).first.materials.map{|m| m.id}
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

  def calculate_cost
    unit_cost = BillingFacadeClient.get_unit_price(@work_plan.proposal.cost_code, @work_plan.product.name)
    if unit_cost.nil?
      add_error("The cost could not be calculated because of missing product cost information.")
      return false
    end
    n = @work_plan.num_samples
    if n.nil?
      add_error("The cost could not be calculated because of missing sample information.")
      return false
    end
    @work_plan.update_attributes(cost_per_sample: unit_cost)
    @work_plan.update_attributes(total_cost: unit_cost*n)
    return true
  end

  def validate_cost_code(project_id)
    cost_code = StudyClient::Node.find(project_id)&.first&.cost_code
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

  def send_order
    if @work_plan.product.availability==false
      add_notice("That product is suspended and cannot currently be ordered.")
      return false
    end
    begin
      @work_plan.send_to_lims
    rescue => e
      Rails.logger.error "Failed to send work order"
      Rails.logger.error e
      Rails.logger.error e.backtrace
      add_error("The request to the LIMS failed.")
      return false
    end

    @work_plan.update_attributes(status: 'active')
    return true
  end

  def add_error(message)
    @messages[:error] = message
  end

  def add_notice(message)
    @messages[:notice] = message
  end

  def generate_submitted_event
    begin
      @work_plan.generate_submitted_event
    rescue StandardError => e
      # Current have to restart the server if there is an exception here
      exception_string = e.backtrace.join("\n")
      WorkOrderMailer.message_queue_error(@work_plan, exception_string).deliver_later
    end
  end
end
