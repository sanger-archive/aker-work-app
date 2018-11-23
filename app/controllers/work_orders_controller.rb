require 'completion_cancel_steps/create_containers_step'
require 'completion_cancel_steps/create_new_materials_step'
require 'completion_cancel_steps/update_old_materials_step'
require 'completion_cancel_steps/lock_set_step'
require 'completion_cancel_steps/update_work_order_step'
require 'completion_cancel_steps/fail_step'


class WorkOrdersController < ApplicationController

  before_action :work_order, only: [:complete, :cancel]

  skip_authorization_check only: [:complete, :cancel, :get, :set_search]
  skip_credentials only: [:complete, :cancel, :get]

  # Returns JSON containing the set service query result for about the set being
  # searched
  def set_search
    connection = Faraday.new(url: "#{Rails.application.config.set_url}")
    begin
      r = connection.get('sets?filter[name]=' + params[:set_name])
      render json: r.body
    rescue Faraday::ConnectionFailed => e
      render json: nil, status: 404
    end
  end

  def create_editable_set
    plan = work_order.work_plan
    authorize! :write, plan
    data = {}
    if !work_order.queued?
      data[:error] = "This work order cannot be modified."
    elsif work_order.set_uuid
      data[:error] = "This work order already has an input set."
    elsif !work_order.original_set_uuid
      data[:error] = "This work order has no original set selected."
    else
      begin
        new_set = work_order.create_editable_set
        data[:view_set_url] = Rails.configuration.urls[:sets] + '/simple/sets/' + new_set.uuid
        data[:new_set_name] = new_set.name
      rescue => e
        Rails.logger.error "create_editable_set failed for work order #{work_order.id}"
        Rails.logger.error e
        e.backtrace.each { |x| Rails.logger.error x}
        data[:error] = "The new set could not be created."
      end
    end
    render json: data.to_json
  end

  # Create a revised output set for a specified job
  def create_revised_set
    job = Job.find(params[:job_id])
    work_order = job.work_order
    plan = work_order.plan
    authorize! :write, plan
    data = {}
    if job.revised_output_set_uuid
      data[:error] = "This job already has a revised output set."
    elsif job.forwarded
      data[:error] = "This job has already been forwarded to the next process."
    elsif !job.output_set_uuid
      data[:error] = "This job does not yet have an output set."
    else
      begin
        new_set = job.decorator.create_editable_set
        data[:view_set_url] = Rails.configuration.urls[:sets] + '/simple/sets/' + new_set.uuid
        data[:new_set_name] = new_set.name
      rescue => e
        Rails.logger.error "create_revised_set failed for job #{job.id}"
        Rails.logger.error e
        e.backtrace.each { |x| Rails.logger.error x }
        data[:error] = "The new set could not be created."
      end
    end
    render json: data.to_json
  end

  # -------- API ---------
  def get
    render json: work_order.lims_data_for_get, status: 200
  rescue ActiveRecord::RecordNotFound
    render json: {errors: [{status: '404', detail: 'Record not found'}]}, status: 404
  end

private

  def work_order
    wo = WorkOrder.find(params[:id])
    @work_order ||= wo.decorate
  end

  helper_method :work_order

end
