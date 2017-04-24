class CreatePermissions < ActiveRecord::Migration[5.0]
  def change
    create_table :permissions do |t|
      t.string :permitted, null: false
      t.boolean :r, null: false, default: false
      t.boolean :w, null: false, default: false
      t.boolean :x, null: false, default: false
      t.references :accessible, null: false, polymorphic:true, type: accessible_id_type, index: true
      t.timestamps
    end
    add_index :permissions, :permitted
  end

  def accessible_id_type
    return 'int' unless Rails.configuration.respond_to? :accessible_id_type
    Rails.configuration.accessible_id_type
  end
end
