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
    plan_groups = WorkPlan.for_user(current_user).order(updated_at: :desc).group_by(&:status)
    @in_construction_plans = plan_groups['construction'] || []
    @active_plans = plan_groups['active'] || []
    @closed_plans = plan_groups['closed'] || []
    @cancelled_plans = plan_groups['cancelled'] || []
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
end
