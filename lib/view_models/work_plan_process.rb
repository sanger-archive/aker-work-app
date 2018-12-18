# frozen_string_literal: true

# A ViewModel for the plan wizard process partial
module ViewModels
  class WorkPlanProcess

    attr_reader :process

    def initialize(args)
      @process               = args.fetch(:process)
      @work_order_collection = args.fetch(:work_orders)
      @work_plan             = args.fetch(:work_plan)
    end

    def process_name
      process.name
    end

    def show_start_jobs_button?
      return false if process == work_plan.processes.last
      process_jobs.any? {|job| !job.forwarded }
    end

    # If a Work Order has been created for this Process, user can no longer change the Process Modules
    def form_enabled?
      work_order_collection.count == 0
    end

    def work_orders
      work_order_collection.map { |work_order| create_work_order_view_model(work_order) }
    end

  private

    attr_reader :work_order_collection, :work_plan

    # All jobs from each of the Process's Work Orders
    def process_jobs
      work_order_collection.map { |work_order| work_order.jobs.concluded }.flatten
    end

    def create_work_order_view_model(work_order)
      ViewModels::WorkOrder.new(work_order: work_order, jobs: work_order.jobs.concluded)
    end

  end
end