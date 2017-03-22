class RemoveOldTables < ActiveRecord::Migration[5.0]
  def change
  	drop_table :item_option_selections
  	drop_table :items
  	drop_table :product_option_values
  	drop_table :product_options
  	drop_table :shops
  end
end
