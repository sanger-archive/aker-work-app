class AddUuidToProductAndProcess < ActiveRecord::Migration[5.1]
  def change
    Aker::ProcessModulePairings.destroy_all
    Aker::ProcessModule.destroy_all
    Aker::ProductProcess.destroy_all
    Aker::Process.destroy_all
    Product.destroy_all
    Catalogue.destroy_all
    add_column :aker_processes, :uuid, :uuid, null: false
    remove_column :aker_processes, :external_id, :integer
    add_column :products, :uuid, :uuid, null: false
    remove_column :products, :external_id, :integer
  end
end
