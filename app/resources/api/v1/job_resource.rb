# frozen_string_literal: true

module Api
  module V1
    class JobResource < JSONAPI::Resource
      attributes :container_uuid, :work_order_id, :started, :completed, :cancelled, :broken,
                 :date_requested, :requested_by, :project, :desired_date, :product,
                 :product_options, :batch_size, :work_plan_comment, :barcode

      paginator :paged

      # We may want to filter jobs by both status and pipeline
      # e.g. /api/v1/jobs?filter[status]=concluded&filter[pipeline]=xxx
      filter :status,
             verify: (lambda do |values, _context|
               raise 'Only querying one status is allowed at present' if values.length > 1

               raise 'Status not valid' unless %w[queued active concluded].include?(values[0])

               values
             end),
             apply: (lambda do |records, values, _options|
               unbroken_jobs = records.joins(work_order: [work_plan: [product: [:processes]]]).where(broken: nil)
               jobs = case values[0]
                      when 'queued'
                        unbroken_jobs.where(started: nil, completed: nil, cancelled: nil)
                      when 'active'
                        unbroken_jobs.where(completed: nil, cancelled: nil)
                                            .where.not(started: nil)
                      when 'concluded'
                        unbroken_jobs.where.not(started: nil)
                                            .where.not(completed: nil)
                                            .or(records.where.not(cancelled: nil))
                      end
               jobs
             end)

      filter :lims,
             # currently we simply pass the values to the apply method as it seems they are already
             # decoded and are strings
             verify: (lambda do |values, _context|
               values
             end),
             apply: (lambda do |records, values, _options|
               return records.none if values.nil?

               return Job.joins(work_order: [work_plan: [product: [:catalogue]]])
                  .where(catalogues: { lims_id: values })
                  .all
             end)

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

      def barcode
        @model.container.barcode
      end

    end
  end
end
