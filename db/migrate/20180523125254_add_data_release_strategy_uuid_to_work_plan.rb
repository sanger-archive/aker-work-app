class AddDataReleaseStrategyUuidToWorkPlan < ActiveRecord::Migration[5.1]
  def change
    add_reference :work_plans, :data_release_strategy, index: true, type: :uuid
    add_foreign_key :work_plans, :data_release_strategies
  end
end
