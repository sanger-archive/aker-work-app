class AddCancelledToWorkPlans < ActiveRecord::Migration[5.1]
  def change
    add_column :work_plans, :cancelled, :datetime, null: true
  end
end
