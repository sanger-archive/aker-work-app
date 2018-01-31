class CreateAkerProcessModulePairings < ActiveRecord::Migration[5.0]
  def change
    create_table :aker_process_module_pairings do |t|
      t.integer :from
      t.integer :to
      t.boolean :default_path, null: false
      t.belongs_to :aker_process, index: true
    end

    add_index :aker_process_module_pairings, [:from, :to], unique: true, name: :index_on_aker_pairings

  end
end
