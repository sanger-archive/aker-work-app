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

  # -------- API ---------
  def get
    render json: work_order.lims_data_for_get, status: 200
  rescue ActiveRecord::RecordNotFound
    render json: {errors: [{status: '404', detail: 'Record not found'}]}, status: 404
  end

  def complete
    finish('complete')
  end

  def cancel
    finish('cancel')
  end

  def finish(finish_status)
    # We need to send JWT in our requests to restful microservices
    #  specifying the work order owner as the responsible user.
    # The JWTSerializer middleware takes the user info from the
    #  request store.

    if BrokerHandle.working?
      RequestStore.store[:x_authorisation] = { email: work_order.owner_email, groups: ['world'] }
      validator = WorkOrderValidatorService.new(work_order, params_for_completion)
      valid = validator.validate?
      if valid
        result = complete_work_order(finish_status)
        if params_for_completion[:work_order][:updated_materials].length >= 1
           work_order.update(material_updated: true)
        end
      else
        result = validator.errors
      end
      render json: { message: result[:msg] }, status: result[:status]
    else
      render json: { message: "RabbitMQ broker is broken" }, status: 500
    end
  end

private

  def params_for_completion
    p = { work_order: params.require(:work_order).as_json.deep_symbolize_keys }

    if p[:work_order][:updated_materials].nil?
      p[:work_order][:updated_materials] = []
    end

    if p[:work_order][:new_materials].nil?
      p[:work_order][:new_materials] = []
    end

    if p[:work_order][:containers].nil?
      p[:work_order][:containers] = []
    end

    if p[:work_order][:updated_materials]
      p[:work_order][:updated_materials].each do |m|
      end
    end
    return p
  end

  def work_order
    @work_order ||= WorkOrder.find(params[:id])
  end

  def text_for_finish_status(finish_status)
    if (finish_status == 'complete')
      return 'completed'
    elsif (finish_status== 'cancel')
      return 'cancelled'
    else
      return finish_status
    end
  end

  def complete_work_order(finish_status)
    success = false
    cleanup = false
    begin
      material_step = CreateNewMaterialsStep.new(work_order, params_for_completion)

      success = DispatchService.new.process([
        CreateContainersStep.new(work_order, params_for_completion),
        material_step,
        UpdateOldMaterialsStep.new(work_order, params_for_completion),
        UpdateWorkOrderStep.new(work_order, params_for_completion, finish_status),
        LockSetStep.new(work_order, params_for_completion, material_step)
      ])

      cleanup = !success
    rescue => e
      puts "*"*70
      puts "Error from dispatch service:"
      puts e
      puts e.backtrace
    ensure
      if !success && !cleanup
        @work_order.broken!
      end
    end

    if success
      msg = flash[:notice] = "Your work order is #{text_for_finish_status(finish_status)}"
      generate_completed_and_cancel_event
    elsif cleanup
      msg = flash[:error] = "The work order could not be #{text_for_finish_status(finish_status)}"
    else
      msg = flash[:error] = "There has been a problem with the work order update. Please contact support."
    end

    return {msg: msg, status: success ? 200 : 502 }
  end

  def generate_completed_and_cancel_event
    work_order.generate_completed_and_cancel_event
  end

  helper_method :work_order

end
