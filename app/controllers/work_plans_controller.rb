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
    @grouped_work_plans = ViewModels::WorkPlanGroups.new(work_plans: work_plans)
  end

  def destroy
    authorize! :write, work_plan

    if work_plan.in_construction?
      work_plan.destroy!
      flash[:notice] = "Work plan deleted."
    elsif work_plan.cancelled?
      flash[:error] = "This work plan has already been cancelled."
    else
      work_plan.update_attributes!(cancelled: Time.now)
      flash[:notice] = "Work plan cancelled."
    end
    redirect_to work_plans_path
  end

private

  def work_plan
    @work_plan ||= WorkPlan.find(params[:id])
  end

  # Gets an list with all the work plans that the current user owns
  # or has spend permisson on the work plans project
  def work_plans
    @work_plans ||= WorkPlan.owned_by_or_permission_to_spend_on(current_user)
  end
end
