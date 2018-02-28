class RenameProductColumnName < ActiveRecord::Migration[5.1]
  def change
    reversible do |dir|
      dir.up do
        rename_column :products, :available, :availability
      end
      dir.down do
        rename_column :products, :availability, :available
      end
    end
  end
end
