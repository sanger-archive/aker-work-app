# Class to handle updating a work order during the work order wizard.
class UpdateOrderService

  attr_reader :messages

  def initialize(work_order_params, work_order, messages)
    @work_order_params = work_order_params
    @work_order = work_order
    @messages = messages
  end

  # This updates a work order during the work order wizard.
  # step — which step in the wizard
  # Returns true if successful; false if fails.
  # Check messages for an error or notice message.
  def perform(step)
    @work_order_params[:status] = step.to_s

    return false if block_any_update
    return false if block_set_change

    return false unless ready_for_step(step)
    return false unless params_satisfy_step(step, @work_order_params)

    if @work_order_params.key?('product_id')
      # force the cost to be recalculated if we're updating the product
      @work_order_params['total_cost'] = nil
    end

    if @work_order.update_attributes(@work_order_params)
      if @work_order.original_set_uuid && @work_order.set_uuid.nil?
        return false unless create_locked_set
      end

      if @work_order.set_uuid && @work_order.product_id && @work_order.total_cost.nil?
        return false unless calculate_cost
      end

      if step==:summary
        return false unless send_order
        add_notice('Your work order has been created.')
        generate_submitted_event
      end
    end

    @work_order.update_attributes(status: next_status(step))
    return true
  end

private

  def next_status(step)
    steps = [:set, :product, :cost, :proposal, :summary]
    i = steps.index(step)
    return step.to_s if i.nil?
    return 'active' if i+1==steps.length
    return steps[i+1].to_s
  end

  def ready_for_step(step)
    return true if step==:set
    unless @work_order.original_set_uuid
      add_error("Please select a set in an earlier step.")
      return false
    end
    return true if step==:product
    unless @work_order.product_id
      add_error("Please select a product in an earlier step.")
      return false
    end
    return true if (step==:cost || step==:proposal)
    unless @work_order.proposal_id
      add_error("Please select a proposal in an earlier step.")
      return false
    end
    return true
  end

  def params_satisfy_step(step, params)
    if step==:set && !params['original_set_uuid']
      add_error("Please select a set to proceed.")
      return false
    end
    if step==:product && !params['product_id']
      add_error("Please select a product to proceed.")
      return false
    end
    if step==:proposal && !params['proposal_id']
      add_error("Please select a proposal to proceed.")
      return false
    end
    return true
  end

  def block_any_update
    if @work_order.active?
      Rails.logger.error "User tried to update an active work order"
      add_error("This work order has already been issued. No further action is possible.")
      return true
    end
  end

  def block_set_change
    selected_set_uuid = @work_order_params['original_set_uuid']
    if (selected_set_uuid && @work_order.set_uuid &&
        selected_set_uuid!=@work_order.original_set_uuid)
      Rails.logger.error "User tried to re-select set after locked set had been created"
      add_error("The sample set for this work order has already been locked. " +
              " To order work for different samples, please start a new work order.")
      return true
    end
  end

  def create_locked_set
    begin
      @work_order.create_locked_set
      return true
    rescue => e
      Rails.logger.error "Failed to create locked set"
      Rails.logger.error e
      Rails.logger.error e.backtrace
      add_error("The request to the set service failed.")
      return false
    end
  end

  def calculate_cost
    cost = @work_order.product&.cost_per_sample
    if cost.nil?
      add_error("The cost could not be calculated because of missing product cost information.")
      return false
    end
    n = @work_order.num_samples
    if n.nil?
      add_error("The cost could not be calculated because of missing sample information.")
      return false
    end
    @work_order.update_attributes(total_cost: cost*n)
    return true
  end

  def send_order
    if @work_order.product.suspended?
      add_notice("That product is suspended and cannot currently be ordered.")
      return false
    end
    begin
      @work_order.send_to_lims
    rescue => e
      Rails.logger.error "Failed to send work order"
      Rails.logger.error e
      Rails.logger.error e.backtrace
      add_error("The request to the LIMS failed.")
      return false
    end

    @work_order.update_attributes(status: 'active')
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
      @work_order.generate_submitted_event
    rescue StandardError => e
      # Current have to restart the server if there is an exception here
      exception_string = e.backtrace.join("\n")
      WorkOrderMailer.message_queue_error(@work_order, exception_string).deliver_later
    end
  end
end
