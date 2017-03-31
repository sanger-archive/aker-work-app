class AddUserToWorkOrder < ActiveRecord::Migration[5.0]
  def change
  	add_column :work_orders, :user_id, :integer
  end
end
