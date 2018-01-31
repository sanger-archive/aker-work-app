class CreateProcessModule < ActiveRecord::Migration[5.0]
  def change
    create_table :process_modules do |t|
      t.string :name
    end
  end
end