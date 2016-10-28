class CreateItemOptionSelections < ActiveRecord::Migration[5.0]
  def change
    create_table :item_option_selections do |t|
      t.references :item, foreign_key: true
      t.references :product_option, foreign_key: true
      t.references :product_option_value, foreign_key: true

      t.timestamps
    end
  end
end
