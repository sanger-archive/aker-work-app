class Jobs::ReviseOutputController < ApplicationController

  # POST /jobs/:id/revise_output
  def create
    authorize! :write, work_plan
    create_revised_set
    redirect_to dispatch_path
  end

private

  def work_plan
    job.work_plan
  end

  def job
    @job ||= Job.find(params[:job_id]).decorate
  end

  def dispatch_path
    work_plan_build_path(work_plan_id: work_plan.id, id: :dispatch, revised_output: job.id)
  end

  def create_revised_set
    if job.revised_output_set_uuid
      flash[:error] = "This job already has a revised output set."
      return false
    elsif job.forwarded
      flash[:error] = "This job has already been forwarded to the next process."
      return false
    elsif !job.output_set_uuid
      flash[:error] = "This job does not yet have an output set."
      return false
    else
      begin
        job.create_editable_set
        return true
      rescue => e
        Rails.logger.error "create_revised_set failed for job #{job.id}"
        Rails.logger.error e
        e.backtrace.each { |x| Rails.logger.error x }
        flash[:error] = "The new set could not be created."
        return false
      end
    end
  end

end