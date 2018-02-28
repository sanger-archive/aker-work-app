class CreateAkerProductProcess < ActiveRecord::Migration[5.0]
  def change
    create_table :aker_product_processes do |t|
      t.references :product, foreign_key: true
      t.references :aker_process, foreign_key: true
      t.integer :stage, null: false
    end
  end
end
