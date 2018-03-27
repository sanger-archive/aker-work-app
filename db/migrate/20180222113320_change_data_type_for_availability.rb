class ChangeDataTypeForAvailability < ActiveRecord::Migration[5.1]

  def change

    reversible do |dir|
      dir.up do
        add_column :products, :available, :boolean, null: false, default: true
        Product.where(availability: true).find_each{|p| p.update_attributes(available: true)}
        Product.where(availability: false).find_each{|p| p.update_attributes(available: false)}
        remove_column :products, :availability, :boolean
      end
      dir.down do
        add_column :products, :availability, :boolean, null: false, default: true
        Product.where(available: false).find_each{|p| p.update_attributes(availability: false)}
        Product.where(available: true).find_each{|p| p.update_attributes(availability: true)}
        remove_column :products, :available, :boolean
      end
    end
  end

end
