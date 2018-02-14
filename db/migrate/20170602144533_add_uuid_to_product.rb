class AddUuidToProduct < ActiveRecord::Migration[5.0]
  def change
  	add_column :products, :product_uuid, :string
  end
end
