# frozen_string_literal: true

# A ViewModel for the plan wizard data release strategy view
module ViewModels
  class WorkPlanDRS

    attr_reader :work_plan

    def initialize(args)
      @work_plan = args.fetch(:work_plan)
      @user      = args.fetch(:user)
    end

    def data_release_strategies
      if work_plan.in_construction?
        DataReleaseStrategyClient.find_strategies_by_user(user.email)
      else
        [work_plan.data_release_strategy]
      end
    end

    def work_plan_drs_id
      work_plan.data_release_strategy_id
    end

    def form_enabled?
      work_plan.in_construction?
    end

  private

    attr_reader :user

  end
end