# frozen_string_literal: true

module Api
  module V1
    class WorkPlanResource < JSONAPI::Resource
      attributes :project_id, :product_id, :owner_email, :comment,
        :uuid, :cancelled, :data_release_strategy_id, :priority

      has_many :work_orders
    end
  end
end
