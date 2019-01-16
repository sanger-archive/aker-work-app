class Jobs::ReviseOutputController < ApplicationController

  # POST /jobs/:id/revise_output
  def create
    authorize! :write, work_plan
    success, value = create_revised_set

    respond_to do |format|
      format.js { render js_render_options(success, value) }
    end
  end

private

  def work_plan
    job.work_plan
  end

  def job
    @job ||= Job.find(params[:job_id]).decorate
  end

  def create_revised_set
    return false, "This job already has a revised output set." if job.revised_output_set_uuid
    return false, "This job has already been forwarded to the next process." if job.forwarded
    return false, "This job does not yet have an output set." if !job.output_set_uuid

    begin
      return true, job.create_editable_set
    rescue => e
      Rails.logger.error "create_revised_set failed for job #{job.id}"
      Rails.logger.error e
      e.backtrace.each { |x| Rails.logger.error x }
      return false, "The new set could not be created."
    end
  end

  def js_render_options(success, value)
    if success
      { status: :created, template: 'jobs/_set_link_with_size', locals: { set: value } }
    else
      { status: :unprocessable_entity, json: { error: value } }
    end
  end

end