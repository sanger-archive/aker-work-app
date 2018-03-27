class MoveProductClassToProcess < ActiveRecord::Migration[5.1]
  def up
    add_column :aker_processes, :process_class, :integer

    Product.find_each do |product|
      product.processes.each do |pro|
        pro.update_attributes(process_class: product.product_class)
      end
    end

    remove_column :products, :product_class, :integer
  end

  def down
    add_column :products, :product_class, :integer
    Product.find_each do |product|
      product.update_attributes(product_class: product.processes.first&.process_class || 0)
    end
    remove_column :aker_processes, :process_class, :integer
  end
end
