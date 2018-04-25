class AddMinMaxValueForProcessModules < ActiveRecord::Migration[5.1]
  def change
    add_column :aker_process_modules, :min_value, :integer
    add_column :aker_process_modules, :max_value, :integer
    add_column :work_order_module_choices, :selected_value, :integer
  end
end
