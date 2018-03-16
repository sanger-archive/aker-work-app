class RemvoeModuleChoicesField < ActiveRecord::Migration[5.0]
  def change
    remove_column :work_orders, :module_choices_id
  end
end
