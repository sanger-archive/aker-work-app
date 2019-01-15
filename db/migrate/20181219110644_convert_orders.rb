# No queued work orders should exist.
# Jobs should be marked as fowarded when the next order has been dispatched.
# Choices should be stored in process_module_choices.
# Work plan with orders should have a cost estimate.

class ConvertOrders < ActiveRecord::Migration[5.2]
  def up
    WorkPlan.all.each { |plan| fix_plan(plan) }
  end

private

  def fix_plan(plan)
    return if plan.work_orders.empty?
    fix_cost(plan)
    fix_choices(plan)
    fix_jobs(plan)
    fix_orders(plan)
  end

  # Store the total estimated cost for the orders against the plan.
  def fix_cost(plan)
    order_costs = plan.work_orders.map(&:total_cost)
    if order_costs.all?
      cost = order_costs.sum
      plan.update_attributes!(estimated_cost: cost)
    end
  end

  # Store the work order's module choices against the process and plan.
  def fix_choices(plan)
    plan.work_orders.each do |order|
      process_id = order.process_id
      order.work_order_module_choices.each do |choice|
        ProcessModuleChoice.create!(
          work_plan: plan, aker_process_id: process_id,
          aker_process_module_id: choice.aker_process_modules_id,
          position: choice.position, selected_value: choice.selected_value
        )
      end
    end
  end

  # Set the job's forwarded date to the date the next order was dispatched.
  def fix_jobs(plan)
    orders = plan.work_orders.to_a
    orders.each_with_index do |order, i|
      dispatch_date = orders[i + 1]&.dispatch_date
      if dispatch_date
        order.jobs.each { |job| job.update_attributes(forwarded: dispatch_date) }
      end
    end
  end

  # Remove any orders that have not been dispatched.
  def fix_orders(plan)
    plan.work_orders.reject(&:dispatch_date).each(&:destroy)
  end
end
