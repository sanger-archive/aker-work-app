# frozen_string_literal: true

# A ViewModel for the plan wizard dispatch view
module ViewModels
  class WorkPlanDispatch

    attr_reader :work_plan

    def initialize(args)
      @work_plan = args.fetch(:work_plan)
    end

    def summary_panel
      @summary_panel ||= WorkPlanSummaryPanel.new(work_plan: work_plan)
    end

    def form_enabled?
      work_plan.in_construction?
    end

    def processes
      work_plan.processes.map { |process| create_work_plan_process(process) }
    end

  private

    def create_work_plan_process(process)
      ViewModels::WorkPlanProcess.new(process: process, work_plan: work_plan, work_orders: process_work_orders(process))
    end

    def process_work_orders(process)
      work_plan.work_orders.object.where(process_id: process.id)
    end

  end
end