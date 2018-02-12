class AddWorkOrderModuleChoices < ActiveRecord::Migration[5.0]
  def change
    create_table :work_order_module_choices do |t|
      t.references :work_order, foreign_key: true
      t.references :aker_process_modules, foreign_key: true
      t.integer :position
    end
    add_reference :work_orders, :module_choices, foreign_key: { to_table: :work_order_module_choices }
  end
end
