# frozen_string_literal: true

# A ViewModel for the plan wizard summary panel partial
module ViewModels
  class WorkPlanSummaryPanel

    attr_reader :work_plan
    delegate :id, :owner_email, to: :work_plan

    def initialize(args)
      @work_plan = args.fetch(:work_plan)
    end

    def work_plan_id
      id
    end

    def created_at
      work_plan.created_at.strftime("%d/%m/%y")
    end

    def original_set_name
      work_plan.original_set.name
    end

    def product_name
      work_plan.product.name
    end

    def project_name
      work_plan.project.name
    end

    def cost_code
      work_plan.project.cost_code
    end

    def data_release_strategy
      work_plan.data_release_strategy.name
    end

  end
end