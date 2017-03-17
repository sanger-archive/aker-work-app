class CreateCatalogues < ActiveRecord::Migration[5.0]
  def change
    create_table :catalogues do |t|
    	t.string :url
    	t.string :lims_id
    	t.string :pipeline
    	t.timestamps
    end
  end
end