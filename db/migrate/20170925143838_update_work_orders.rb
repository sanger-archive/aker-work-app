class UpdateWorkOrders < ActiveRecord::Migration[5.0]
  def change
    add_column :work_orders, :owner_email, :string

    WorkOrder.where.not(user_id: nil).each do |wo|
      wo.update_attributes(owner_email: User.find(wo.user_id).email)
    end

    add_index :work_orders, :owner_email
  end
end
