class AddPriorityToWorkPlan < ActiveRecord::Migration[5.1]
  def change
    add_column :work_plans, :priority, :string, default: 'standard', null: false
  end
end
