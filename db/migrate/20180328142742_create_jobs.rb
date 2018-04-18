class CreateJobs < ActiveRecord::Migration[5.1]
  def change
    create_table :jobs, id: :serial do |t|
      t.uuid :container_uuid
      t.datetime :started
      t.datetime :completed
      t.datetime :cancelled
      t.datetime :broken
      t.references :work_order, foreign_key: true, null: false
    end
  end
end
