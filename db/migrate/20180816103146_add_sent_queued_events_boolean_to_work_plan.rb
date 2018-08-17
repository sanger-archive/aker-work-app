class AddSentQueuedEventsBooleanToWorkPlan < ActiveRecord::Migration[5.2]
  def up
    add_column :work_plans, :sent_queued_events, :boolean, null: false, default: false

    # Assume that all the existing work plans that have work orders have already
    # sent their events
    WorkPlan.find_each do |plan|
      unless plan.work_orders.empty?
        plan.update_attributes(sent_queued_events: true)
      end
    end
  end

  def down
    remove_column :work_plans, :sent_queued_events
  end
end
