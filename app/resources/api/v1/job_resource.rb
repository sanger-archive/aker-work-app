module Api
  module V1
    class JobResource < JSONAPI::Resource
      attributes :container_uuid, :work_order_id, :started, :completed, :cancelled, :broken,
                 :date_requested, :requested_by, :project, :desired_date, :product, :product_options,
                 :batch_size, :work_plan_comment


      # We may want to filter jobs by both status and pipeline
      # e.g. /api/v1/jobs?filter[status]=concluded&filter[pipeline]=xxx

      filter :status, apply: ->(records, value, _options) {
        if value[0] == 'queued'
          records.queued
        elsif value[0] == 'active'
          records.active
        elsif value[0] == 'concluded'
          records.concluded
        end
      }

      filter :pipeline, apply: ->(records, value, _options) {
        pipeline = value[0]
        return records.none if value.nil?
        records.get_jobs_for_pipeline(pipeline)
      }

      def date_requested
        @model.work_order&.dispatch_date
      end

      def requested_by
        @model.work_order&.work_plan&.owner_email
      end

      def project
        @model.work_order&.work_plan&.project&.name
      end

      def desired_date
        @model.work_order&.work_plan&.desired_date
      end

      def product
        @model.work_order&.work_plan&.product&.name
      end

      def product_options
        @model.work_order&.work_plan&.product&.processes&.map(&:name)
      end

      def batch_size
        @model&.material_ids&.length
      end

      def work_plan_comment
        @model.work_order&.work_plan&.comment
      end
    end
  end
end