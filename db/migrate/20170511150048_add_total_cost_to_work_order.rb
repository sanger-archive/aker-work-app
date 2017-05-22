class AddTotalCostToWorkOrder < ActiveRecord::Migration[5.0]
  def change
    add_column :work_orders, :total_cost, :int
  end
end
