class CreateProductProcess < ActiveRecord::Migration[5.0]
  def change
    create_table :product_processes do |t|
      t.belongs_to :product, index: true
      t.belongs_to :process, index: true
      t.integer :stage
    end
  end
end