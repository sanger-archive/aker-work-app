
# Supports revising the options chosen for one process in a work plan that
# may already be in progress.
class ReviseOptionsService
  attr_reader :plan

  def process
    @process ||= Aker::Process.find(@process_id)
  end

  def product
    plan.product
  end

  def modules
    @modules ||= @module_ids.map { |mid| Aker::ProcessModule.find(mid) }
  end

  def initialize(plan, process_id, module_ids, values, user_and_groups, messages)
    @plan = plan
    @process_id = process_id
    @module_ids = module_ids
    @values = values
    @user_and_groups = user_and_groups
    @messages = messages
  end

  def checks
    return error("Please select a set for this work plan in an earlier step.") unless plan.original_set_uuid
    return error("This plan has no product selected.") unless product
    return error("Please select a project for this work plan in an earlier step.") unless plan.project_id
    return false unless helper.parent_cost_code(plan.project_id)
    return error("The specified process is not part of this plan's product.") unless product.processes.include? process
    return error("Work for this process has already been dispatched.") if plan.work_orders.any? { |order| order.process==process }

    return error("The selected modules are not suitable for this process.") unless helper.modules_ok_for_process(@module_ids, process)
    return error("The selected values are not suitable for this process.") unless helper.module_values_ok(@module_ids, @values)
    return false unless helper.predict_unit_price(plan.project_id, modules.map(&:name))
    # We don't update the cost estimate for the plan, because it's impossible to reasonably reflect how many orders and samples will be done

    return true
  end

  # This should be called inside a transaction
  def perform
    return false unless checks

    plan.modules_for_process_id(@process_id).each(&:destroy)
    helper.create_module_choices(plan, process, @module_ids, @values)
    return true
  end

private

  def helper
    @helper ||= PlanHelper.new(plan, @user_and_groups, @messages)
  end

  def error(message)
    @messages[:error] = message
    false
  end

end
