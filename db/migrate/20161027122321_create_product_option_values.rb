class CreateProductOptionValues < ActiveRecord::Migration[5.0]
  def change
    create_table :product_option_values do |t|
      t.references :product_option, foreign_key: true
      t.string :value

      t.timestamps
    end
  end
end
