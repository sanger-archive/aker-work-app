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
end
