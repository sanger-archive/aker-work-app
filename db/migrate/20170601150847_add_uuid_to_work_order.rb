class AddUuidToWorkOrder < ActiveRecord::Migration[5.0]
  def change
  	add_column :work_orders, :work_order_uuid, :string
  end
end
