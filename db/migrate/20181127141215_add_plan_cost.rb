class AddPlanCost < ActiveRecord::Migration[5.2]
  def change
    add_column :work_plans, :estimated_cost, :decimal, precision: 8, scale: 2
  end
end
