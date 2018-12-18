# frozen_string_literal: true

# A ViewModel for the plan wizard project view
module ViewModels
  class WorkPlanProject

    attr_reader :work_plan

    def initialize(args)
      @work_plan = args.fetch(:work_plan)
      @user      = args.fetch(:user)
    end

    def projects
      Study.spendable_projects(user)
    end

    def form_enabled?
      work_plan.in_construction?
    end

    private

    attr_reader :user

  end
end