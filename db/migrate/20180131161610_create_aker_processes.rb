class CreateAkerProcesses < ActiveRecord::Migration[5.0]
  def change
    create_table :aker_processes do |t|
      t.integer :external_id
      t.string :name, null: false
      t.integer :TAT
    end
  end
end