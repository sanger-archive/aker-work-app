class AddFieldsToProducts < ActiveRecord::Migration[5.0]
  def change
  	remove_column :products, :shop_id
  	add_reference :products, :catalogue, index: true
    add_foreign_key :products, :catalogues
    add_column :products, :TAT, :integer
    add_column :products, :cost_per_sample, :integer
    add_column :products, :requested_biomaterial_type, :string
    add_column :products, :product_version, :integer
    add_column :products, :availability, :string
    add_column :products, :description, :string
  end
end
