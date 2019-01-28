class WorkPlans::DispatchController < ApplicationController

  before_action :work_plan, only: :update

  def update
    authorize! :write, work_plan
    dispatch_work_plan
    redirect_to dispatch_path
  end

  private

  def dispatch_work_plan
    work_plan.update_attributes!(update_params)
    dispatch_plan_service.perform
    flash[:notice] = success_message
  rescue StandardError => exception
    flash[:alert] = exception.message
  end

  def work_plan
    @work_plan ||= WorkPlan.find(params[:work_plan_id])
  end

  def update_params
    params.require(:work_plan).permit(:comment, :priority)
  end

  def dispatch_plan_service
    DispatchPlanService.new(work_plan, user_and_groups, flash)
  end

  def user_and_groups
    [current_user.email] + current_user.groups
  end

  def dispatch_path
    work_plan_build_path(work_plan_id: params[:work_plan_id], id: :dispatch)
  end

  def success_message
    %(
    Work Plan started.

    You will receive an email when the first Work Order has been dispatched to the LIMS.
    )
  end

end