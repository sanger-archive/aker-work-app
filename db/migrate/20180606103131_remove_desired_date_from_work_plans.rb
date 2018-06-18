class RemoveDesiredDateFromWorkPlans < ActiveRecord::Migration[5.1]
  def change
    remove_column :work_plans, :desired_date
  end
end
