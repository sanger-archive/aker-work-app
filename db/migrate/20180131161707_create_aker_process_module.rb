class CreateAkerProcessModule < ActiveRecord::Migration[5.0]
  def change
    create_table :aker_process_modules do |t|
      t.string :name, null: false
    end
  end
end