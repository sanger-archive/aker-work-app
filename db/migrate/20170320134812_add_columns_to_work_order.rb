class AddColumnsToWorkOrder < ActiveRecord::Migration[5.0]
  def change
  	add_column :work_orders, :comment, :string
  	add_column :work_orders, :desired_date, :date
  	add_reference :work_orders, :product, index: true
    add_foreign_key :work_orders, :products
  end
end
