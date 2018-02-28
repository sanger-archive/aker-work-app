class UpdateProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :external_id, :integer
    remove_column :products, :TAT, :integer
    remove_column :products, :product_uuid, :string
  end
end
