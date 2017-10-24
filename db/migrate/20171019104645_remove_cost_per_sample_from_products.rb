class RemoveCostPerSampleFromProducts < ActiveRecord::Migration[5.0]
  def change
    ActiveRecord::Base.transaction do
      add_column :work_orders, :cost_per_sample, :decimal, precision: 8, scale: 2
      change_column :work_orders, :total_cost, :decimal, precision: 8, scale: 2
      remove_column :products, :cost_per_sample
    end
  end
end
