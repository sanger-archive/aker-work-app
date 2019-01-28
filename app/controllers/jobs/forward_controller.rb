class Jobs::ForwardController < ApplicationController

  before_action :jobs, only: :create

  # POST /jobs/forward
  def create
    authorize_work_plans!
    dispatch_next_order
    redirect_to dispatch_path
  end

  private

  def authorize_work_plans!
    work_plans.each { |work_plan| authorize! :write, work_plan }
  end

  # Possible that someone (maliciously?) could try and forward Jobs from different Work Plans
  def work_plans
    jobs.map(&:work_plan)
  end

  def jobs
    @jobs ||= Job.find(params[:job_ids])
  end

  def dispatch_next_order
    dispatch_next_order_service.execute
    flash[:notice] = success_message
  rescue StandardError => exception
    flash[:error] = exception.message
  end

  def dispatch_next_order_service
    DispatchNextOrderService.new(job_ids, user_and_groups, flash)
  end

  def job_ids
    jobs.pluck(:id)
  end

  def user_and_groups
    [current_user.email] + current_user.groups
  end

  def dispatch_path
    work_plan_build_path(work_plan_id: work_plans.first.id, id: :dispatch)
  end

  def success_message
    %(
      New Work Order created and queued for dispatch.

      You will receive an email when this Work Order has been dispatched to the LIMS.
    )
  end

end