class AddInputSetUuidToJob < ActiveRecord::Migration[5.2]
  def change
    add_column :jobs, :input_set_uuid, :uuid
  end
end
