class AddSetUuidToJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :jobs, :set_uuid, :uuid, null: true
  end
end
