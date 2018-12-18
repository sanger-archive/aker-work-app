class ChangeSetFields < ActiveRecord::Migration[5.2]
  def change
    rename_column :jobs, :set_uuid, :output_set_uuid
    add_column :jobs, :revised_output_set_uuid, :uuid

    remove_column :work_orders, :original_set_uuid, :uuid
    remove_column :work_orders, :finished_set_uuid, :uuid

    add_column :jobs, :forwarded, :datetime
  end
end
