class ChangeWorkOrdersForPlans < ActiveRecord::Migration[5.1]
  def change
    AkerPermissionGem::Permission.destroy_all
    WorkOrder.destroy_all

    remove_column :work_orders, :proposal_id, :integer
    remove_column :work_orders, :owner_email, :citext, null: false
    remove_column :work_orders, :comment, :string
    remove_column :work_orders, :desired_date, :date
    remove_column :work_orders, :product_id, :integer
    remove_column :work_orders, :original_set_uuid, :string
    remove_column :work_orders, :set_uuid, :string
    remove_column :work_orders, :finished_set_uuid, :string
    remove_column :work_orders, :work_order_uuid, :string, null: false

    add_column :work_orders, :order_index, :integer, null: false
    add_column :work_orders, :dispatch_date, :date
    add_column :work_orders, :completion_date, :date
    add_column :work_orders, :original_set_uuid, :uuid
    add_column :work_orders, :set_uuid, :uuid
    add_column :work_orders, :finished_set_uuid, :uuid
    add_column :work_orders, :work_order_uuid, :uuid, null: false

    add_reference :work_orders, :work_plan, foreign_key: true, null: false
    add_reference :work_orders, :process, index: true, foreign_key: { to_table: :aker_processes }, null: false
  end
end
