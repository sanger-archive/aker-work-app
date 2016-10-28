class CreateItems < ActiveRecord::Migration[5.0]
  def change
    create_table :items do |t|
      t.references :work_order, foreign_key: true
      t.references :product, foreign_key: true

      t.timestamps
    end
  end
end
