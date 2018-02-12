class ProductChanges < ActiveRecord::Migration[5.0]
  def change
    # Remove external_id from product module pairings table
    remove_column :aker_process_module_pairings, :external_id, :integer

    # Add aker_process_id to the index_on_aker_pairings
    remove_index :aker_process_module_pairings, name: :index_on_aker_pairings
    add_index :aker_process_module_pairings, [:from_step_id, :to_step_id, :aker_process_id], unique: true, name: :index_on_aker_pairings
  end
end
