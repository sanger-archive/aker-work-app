class DropUsers < ActiveRecord::Migration[5.0]
  def change
    remove_column :work_orders, :user_id
    drop_table :users
  end
end
