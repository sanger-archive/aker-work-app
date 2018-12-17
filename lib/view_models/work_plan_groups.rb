# frozen_string_literal: true

# A helper class for work plans #index view, grouping plans by status
module ViewModels
  class WorkPlanGroups
    attr_reader :work_plans

    def initialize(args = {})
      @work_plans = args.fetch(:work_plans, WorkPlan.all)
    end

    def in_construction
      grouped_work_plans['construction'] || []
    end

    def active
      grouped_work_plans['active'] || []
    end

    def cancelled
      grouped_work_plans['cancelled'] || []
    end

    def any_in_construction?
      in_construction.length.positive?
    end

    def any_active?
      active.length.positive?
    end

    def any_cancelled?
      cancelled.length.positive?
    end

    private

    def grouped_work_plans
      @grouped_work_plans ||= work_plans.order(updated_at: :desc).group_by(&:status)
    end
  end
end