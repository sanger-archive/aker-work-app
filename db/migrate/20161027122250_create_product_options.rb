class CreateProductOptions < ActiveRecord::Migration[5.0]
  def change
    create_table :product_options do |t|
      t.references :product, foreign_key: true
      t.string :name

      t.timestamps
    end
  end
end
