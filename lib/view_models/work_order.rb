# frozen_string_literal: true

# A ViewModel for the work order partial
module ViewModels
  class WorkOrder
    include WorkOrdersHelper

    delegate :id, to: :work_order

    def initialize(args)
      @work_order   = args.fetch(:work_order)
      @jobs         = args.fetch(:jobs, @work_order.jobs)
      @last_process = args.fetch(:last_process)
    end

    def jobs
      @jobs.map { |job| ViewModels::Job.new(job: job.decorate, last_process: last_process) }
    end

    def work_order_id
      id
    end

    def status_label
      work_order_status_label(work_order)
    end

    def dispatch_date
      work_order.dispatch_date&.to_s(:short)
    end

    def completion_date
      work_order.concluded? ? work_order_completion_date : work_order_estimated_completion_date
    end

    # Note: this is the total number of Jobs in the Work Order. Not just the ones we show in the View
    # i.e. it counts unconcluded Jobs too
    def number_of_jobs
      work_order.jobs.size
    end

    # Show the jobs table only if we actually have concluded Jobs to show
    def show_jobs?
      jobs.size > 0
    end

    def show_revised_column?
      !last_process?
    end

    def show_check_box?
      return false if last_process?
      jobs.any? { |job| !job.forwarded? }
    end

  private

    attr_reader :work_order, :last_process

    def last_process?
      last_process
    end

    def work_order_completion_date
      "Completion Date: #{work_order.completion_date&.to_s(:short)}"
    end

    def work_order_estimated_completion_date
      "Estimated Completion Date: #{work_order.estimated_completion_date&.to_s(:short)}"
    end

  end
end