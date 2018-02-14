class AddSetToWorkOrder < ActiveRecord::Migration[5.0]
  def change
    add_column :work_orders, :original_set_uuid, :string
    add_column :work_orders, :set_uuid, :string
  end
end
