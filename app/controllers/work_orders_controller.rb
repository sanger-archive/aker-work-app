require 'completion_cancel_steps/create_containers_step'
require 'completion_cancel_steps/create_new_materials_step'
require 'completion_cancel_steps/update_old_materials_step'
require 'completion_cancel_steps/lock_set_step'
require 'completion_cancel_steps/update_work_order_step'
require 'completion_cancel_steps/fail_step'


class WorkOrdersController < ApplicationController

  # SSO
  before_action :check_user_signed_in

  before_action :work_order, only: [:show, :complete, :cancel]

  skip_authorization_check :only => [:index, :complete, :cancel, :get]

  def index
    @active_work_orders = WorkOrder.active.for_user(current_user).order(created_at: :desc)
    @pending_work_orders = WorkOrder.pending.for_user(current_user).order(created_at: :desc)
    @completed_work_orders = WorkOrder.completed.for_user(current_user).order(created_at: :desc)
    @cancelled_work_orders = WorkOrder.cancelled.for_user(current_user).order(created_at: :desc)
  end

  def create
    authorize! :create, WorkOrder

    work_order = WorkOrder.create!(owner_email: current_user.email)

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

  # -------- API ---------
  def get
    render json: work_order.lims_data, status: 200
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
    validator = WorkOrderValidatorService.new(work_order, params_for_completion)
    valid = validator.validate?
    if valid
      result = complete_work_order(finish_status)
    else
      result = validator.errors
    end
    render json: { message: result[:msg] }, status: result[:status]
  end

private

  def check_user_signed_in
    redirect_to Rails.configuration.login_url unless current_user
  end

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
      msg = flash[:notice] = 'Your work order is updated'
      generate_completed_and_cancel_event
    elsif cleanup
      msg = flash[:error] = "The work order could not be updated"
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
