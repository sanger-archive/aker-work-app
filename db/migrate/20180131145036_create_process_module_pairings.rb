class CreateProcessModulePairings < ActiveRecord::Migration[5.0]
  def change
    create_table :process_module_pairings do |t|
      t.integer :from, null: true
      t.integer :to, null: true
      t.boolean :default_path
      t.belongs_to :process, index: true
    end

    add_index :process_module_pairings, [:from, :to], unique: true, name: :index_on_pairings

  end
end
