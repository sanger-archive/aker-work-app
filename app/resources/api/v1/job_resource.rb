# frozen_string_literal: true

module Api
  module V1
    # JSONAPI resource defining a job
    class JobResource < JSONAPI::Resource
      attributes :uuid, :container_uuid, :work_order_id, :started, :completed, :cancelled, :broken,
                 :date_requested, :requested_by, :project_and_costcode, :product,
                 :process_modules, :batch_size, :work_plan_comment, :priority, :barcode, :process,
                 :set

      paginator :paged

      has_one :work_order

      # We may want to filter jobs by both status and pipeline
      # e.g. /api/v1/jobs?filter[status]=concluded&filter[pipeline]=xxx
      filter :status,
             verify: (lambda do |values, _context|
               raise 'Only querying one status is allowed at present' if values.length > 1

               raise 'Status not valid' unless %w[queued active concluded].include?(values[0])

               values
             end),
             apply: (lambda do |records, values, _options|
               unbroken_jobs = records.where(broken: nil)
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

      def self.sortable_fields(context)
        super + %i[work_order.dispatch_date work_order.id work_plan.priority]
      end

      def self.apply_sort(records, order_options, context = {})
        if order_options.key?('work_plan.priority')
          records = records.prioritised(order_options['work_plan.priority'])
          order_options.delete('work_plan.priority')
        end
        super(records, order_options, context)
      end

      def date_requested
        @model.work_order&.dispatch_date
      end

      def requested_by
        @model.work_order&.work_plan&.owner_email
      end

      def project
        @model.work_order&.work_plan&.project&.name
      end

      def costcode
        @model.work_order&.work_plan&.project&.cost_code
      end

      def project_and_costcode
        project + " (#{costcode})" if project
      end

      def priority
        @model.work_order&.work_plan&.priority
      end

      def product
        @model.work_order&.work_plan&.product&.name
      end

      def process
        @model.work_order&.process&.name
      end

      def process_modules
        @model.work_order_module_choices.map(&:description).join(', ')
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

      def set
        @model&.set
      end
    end
  end
end
