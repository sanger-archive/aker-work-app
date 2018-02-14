class AddFinishedSetToWorkOrder < ActiveRecord::Migration[5.0]
  def change
    add_column :work_orders, :finished_set_uuid, :string
  end
end
