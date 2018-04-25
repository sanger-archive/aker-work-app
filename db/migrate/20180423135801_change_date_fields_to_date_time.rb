class ChangeDateFieldsToDateTime < ActiveRecord::Migration[5.1]
  def change
    change_column :work_orders, :dispatch_date, :datetime
    change_column :work_orders, :completion_date, :datetime
  end
end
