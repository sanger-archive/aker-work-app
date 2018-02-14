class UpdateWorkOrders < ActiveRecord::Migration[5.0]
  def change
    add_column :work_orders, :owner_email, :string
    add_index :work_orders, :owner_email
  end
end
