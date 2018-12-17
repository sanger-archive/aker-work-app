# frozen_string_literal: true

module Api
  module V1
    class WorkOrderResource < JSONAPI::Resource
      attributes :status, :total_cost, :cost_per_sample, :material_updated,
        :dispatch_date, :original_set_uuid, :set_uuid, :work_order_uuid, :work_plan_id, :process_id

      has_many :jobs
      has_one :work_plan

      def self.sortable_fields(context)
        super + [:"work_plan.priority"]
      end
    end
  end
end
