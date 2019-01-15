class CreateProcessModuleChoices < ActiveRecord::Migration[5.2]
  def change
    create_table :process_module_choices do |t|
      t.references :work_plan, foreign_key: true, null: false
      t.references :aker_process, foreign_key: true, null: false
      t.references :aker_process_module, foreign_key: true, null: false
      t.integer :position, null: false
      t.integer :selected_value
      t.timestamps
    end
  end
end
