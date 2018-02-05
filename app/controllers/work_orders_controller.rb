require 'completion_cancel_steps/create_containers_step'
require 'completion_cancel_steps/create_new_materials_step'
require 'completion_cancel_steps/update_old_materials_step'
require 'completion_cancel_steps/lock_set_step'
require 'completion_cancel_steps/update_work_order_step'
require 'completion_cancel_steps/fail_step'


class WorkOrdersController < ApplicationController

  before_action :work_order, only: [:show, :complete, :cancel]

  skip_authorization_check only: [:index, :complete, :cancel, :get, :set_search]
  skip_credentials only: [:complete, :cancel, :get]

  def index
    @active_work_orders = WorkOrder.active.for_user(current_user).order(created_at: :desc)
    @pending_work_orders = WorkOrder.pending.for_user(current_user).order(created_at: :desc)
    @completed_work_orders = WorkOrder.completed.for_user(current_user).order(created_at: :desc)
    @cancelled_work_orders = WorkOrder.cancelled.for_user(current_user).order(created_at: :desc)
  end

  def create
    authorize! :create, WorkOrder

    work_order = WorkOrder.create!(owner_email: current_user.email, original_set_uuid: params[:set_id])

    redirect_to work_order_build_path(
      id: Wicked::FIRST_STEP,
      work_order_id: work_order.id
    )
  end

  def destroy
    authorize! :write, work_order

    if work_order.active?
      flash[:error] = "This work order has already been issued, and cannot be cancelled."
    else
      work_order.destroy
      flash[:notice] = "Work order cancelled"
    end
    redirect_to work_orders_path
  end

  def show
    authorize! :read, work_order
  end

  # Returns JSON containing the set service query result for about the set being
  # searched
  def set_search
    connection = Faraday.new(url: "#{Rails.application.config.set_url}#{Rails.application.config.relative_url_root}")
    begin
      r = connection.get('sets?filter[name]=' + params[:set_name])
      render json: r.body
    rescue Faraday::ConnectionFailed => e
      render json: nil, status: 404
    end
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
    begin
      work_order.generate_completed_and_cancel_event
    rescue StandardError => e
      # Current have to restart the server if there is an exception here
      exception_string = e.backtrace.join("\n")
      WorkOrderMailer.message_queue_error(work_order, exception_string).deliver_later
    end
  end

  helper_method :work_order

end
