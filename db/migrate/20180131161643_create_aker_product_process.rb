class CreateAkerProductProcess < ActiveRecord::Migration[5.0]
  def change
    create_table :aker_product_processes do |t|
      t.belongs_to :product, index: true
      t.belongs_to :aker_process, index: true
      t.integer :stage, null: false
    end
  end
end
