class CreateDataReleaseStrategiesTable < ActiveRecord::Migration[5.1]
  def change
    enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')

    create_table :data_release_strategies, id: :uuid, default: 'uuid_generate_v4()' do |t|
      t.string :name
      t.string :study_code

      t.timestamps
    end

    add_index :data_release_strategies, :id, unique: true
  end
end
