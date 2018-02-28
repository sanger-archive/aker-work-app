class CreateAkerProcessModule < ActiveRecord::Migration[5.0]
  def change
    create_table :aker_process_modules do |t|
      t.string :name, null: false
      t.references :aker_process, foreign_key: true
    end
    add_index :aker_process_modules, [:aker_process_id, :name], unique: true
  end
end