class AddProductClassToProduct < ActiveRecord::Migration[5.0]
  def change
  	add_column :products, :product_class, :integer
  end
end
