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

    if @work_order.update_attributes(@work_order_params)
      if @work_order.original_set_uuid && @work_order.set_uuid.nil?
        return false unless create_locked_set
      end

      if step==:summary
        return false unless send_order
        @work_order.update_attributes(status: 'active')
        add_notice('Your work order has been created.')
      end
    end

    return true
  end

private

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
end
