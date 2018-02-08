class CreateAkerProcessModulePairings < ActiveRecord::Migration[5.0]
  def change
    create_table :aker_process_module_pairings do |t|
      t.references :from_step
      t.references :to_step
      t.integer :external_id
      t.boolean :default_path, null: false
      t.belongs_to :aker_process, index: true
    end
    add_index :aker_process_module_pairings, [:from_step_id, :to_step_id], unique: true, name: :index_on_aker_pairings
  end
end
