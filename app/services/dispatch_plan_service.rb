require 'broker'
require 'uuid'

# Handles a request to dispatch the first order in a work plan
class DispatchPlanService
  attr_reader :plan

  def initialize(plan, user_and_groups, messages)
    @plan = plan
    @messages = messages
    @user_and_groups = user_and_groups
  end

  def checks
    return error("This work plan is already underway.") unless plan.work_orders.empty?
    return error("No set is selected for this work plan.") unless plan.original_set_uuid
    return error("No project is selected for this work plan.") unless plan.project_id
    return error("No product is selected for this work plan.") unless plan.product_id

    return false unless find_parent_cost_code(plan.project_id)
    return false unless helper.authorize_project(plan.project_id)
    return false unless helper.validate_data_release_strategy_selection(plan.data_release_strategy_id)
    return false unless helper.check_set_contents(plan.original_set_uuid)
    return false unless helper.check_broker
    return false unless predict_plan_cost
    unless plan.product.available?
      @messages[:notice] = "That product is suspended and cannot currently be ordered."
      return false
    end

    return true
  end

  def perform
    return false unless checks

    plan.update_attributes!(estimated_cost: @plan_unit_price * plan.decorate.original_set.meta[:size])

    order = create_order

    raise "The work order could not be split into jobs." unless work_order_splitter.split(order)

    unless work_order_dispatcher.dispatch(order)
      Rails.logger.error work_order_dispatcher.errors.full_messages
      raise "The request to the LIMS failed."
    end

    true
  end

  def find_parent_cost_code(project_id)
    @cost_code = helper.parent_cost_code(project_id)
    return true if @cost_code.present?
    @messages[:error] ||= "The code code could not be retrieved."
    return false
  end

  def generate_dispatched_event(order_id)
    order = WorkOrder.find(order_id)
    order.generate_dispatched_event
  end

  def predict_plan_cost
    @plan_unit_price = nil

    project_id = plan.project_id
    return error("This plan has no project.") unless project_id

    module_names = plan.process_module_choices.map { |choice| choice.process_module.name }
    return error("This plan has no modules selected.") if module_names.empty?

    @plan_unit_price = helper.predict_unit_price(project_id, module_names)

    return @plan_unit_price.present?
  end

  def create_order
    process = plan.product.processes.first
    module_choices = plan.modules_for_process_id(process.id).to_a
    module_names = module_choices.map { |choice| choice.process_module.name }
    module_costs = UbwClient::get_unit_prices(module_names, @cost_code)
    unit_price = module_names.sum { |modname| module_costs[modname] }

    order = WorkOrder.create!(process: process, order_index: 0, work_plan: plan, status: WorkOrder.QUEUED)
    order_set = plan.decorate.original_set.create_locked_clone(order.name)
    order_cost = unit_price * order_set.meta[:size]
    order.update_attributes!(cost_per_sample: unit_price, total_cost: order_cost, set_uuid: order_set.uuid)

    module_choices.each_with_index do |choice, i|
      WorkOrderModuleChoice.create!(work_order_id: order.id, aker_process_modules_id: choice.aker_process_module_id,
                                    position: i, selected_value: choice.selected_value)
    end

    order.reload
  end

private

  def error(message)
    @messages[:error] = message
    false
  end

  def work_order_dispatcher
    @dispatcher ||= WorkOrderDispatcher.new(serializer: WorkOrderSerializer.new)
  end

  def work_order_splitter
    @splitter ||= WorkOrderSplitter::ByContainer.new
  end

  def helper
    @helper ||= PlanHelper.new(plan, @user_and_groups, @messages)
  end

end
