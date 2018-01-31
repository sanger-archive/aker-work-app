class CreateProcesses < ActiveRecord::Migration[5.0]
  def change
    create_table :processes do |t|
      t.string :name
      t.integer :TAT
    end
  end
end