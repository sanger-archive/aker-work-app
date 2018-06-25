# frozen_string_literal: true

module Api
  module V1
    class WorkOrderResource < JSONAPI::Resource
      attributes :status, :total_cost, :cost_per_sample, :material_updated,
        :dispatch_date, :original_set_uuid, :set_uuid, :finished_set_uuid,
        :work_order_uuid, :work_plan_id, :process_id

      has_many :jobs
      belongs_to :work_plan
    end
  end
end
