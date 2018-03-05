class WorkPlansController < ApplicationController
  skip_authorization_check only: [:index, :complete, :cancel, :get, :set_search]


  def create
    authorize! :create, WorkPlan

    work_plan = WorkPlan.create!(owner_email: current_user.email)

    redirect_to work_plan_build_path(
      id: Wicked::FIRST_STEP,
      work_plan_id: work_plan.id
    )
  end

  def index
    users_work_plans = WorkPlan.for_user(current_user).order(updated_at: :desc)
    @in_construction_plans = users_work_plans.select(&:in_construction?)
    @active_plans = users_work_plans.select(&:active?)
    @closed_plans = users_work_plans.select(&:closed?)
  end
end
