class AddCostCodeToWorkOrder < ActiveRecord::Migration[5.0]
  def change
    add_column :work_orders, :cost_code, :string
  end
end
