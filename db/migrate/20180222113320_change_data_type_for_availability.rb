class ChangeDataTypeForAvailability < ActiveRecord::Migration[5.1]

  def change
    add_column :products, :available, :boolean, null: false, default: true
    Product.where(availability: 'available').find_each{|p| p.update_attributes(available: true)}
    Product.where(availability: 'suspended').find_each{|p| p.update_attributes(available: false)}
    remove_column :products, :availability, :boolean
  end

end
