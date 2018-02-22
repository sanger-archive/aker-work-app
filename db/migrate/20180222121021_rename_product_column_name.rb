class RenameProductColumnName < ActiveRecord::Migration[5.1]
  def change
    rename_column :products, :available, :availability
  end
end
