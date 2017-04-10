class CreatePermissions < ActiveRecord::Migration[5.0]
  def change
    create_table :permissions do |t|
      t.string :permitted
      t.boolean :r
      t.boolean :w
      t.boolean :x
      t.references :accessible, polymorphic: true
    end
    add_index :permissions, :permitted
  end
end
