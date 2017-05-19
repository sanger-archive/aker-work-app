require 'completion_cancel_steps/create_containers_step'
require 'completion_cancel_steps/create_new_materials_step'
require 'completion_cancel_steps/lock_set_step'
require 'completion_cancel_steps/update_old_materials_step'
require 'completion_cancel_steps/update_work_order_step'


class WorkOrdersController < ApplicationController

  before_action :work_order, only: [:show, :complete, :cancel]

  skip_authorization_check :only => [:index, :complete]


  def index
    if user_signed_in?
      @active_work_orders = WorkOrder.active.for_user(current_user)
      @pending_work_orders = WorkOrder.pending.for_user(current_user)
    else
      @active_work_orders = []
      @pending_work_orders = []
    end
  end

  def create
    authorize! :create, WorkOrder

    work_order = WorkOrder.create!(user: current_user)

    redirect_to work_order_build_path(
      id: Wicked::FIRST_STEP,
      work_order_id: work_order.id
    )
  end

  def destroy
    authorize! :create, work_order

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

  def complete
    validator = WorkOrderValidatorService.new(work_order, params_for_completion)
    valid = validator.validate?
    if valid
      debugger
      result = complete_work_order
    else
      result = validator.errors
    end
    render json: { message: result[:msg] }, :status => result[:status]
  end

  def cancel
  end

private

  def params_for_completion
    { work_order: params.require(:work_order).as_json.deep_symbolize_keys }
  end

  def work_order
    @work_order ||= WorkOrder.find(params[:id])
  end

  def complete_work_order

    success = false
    cleanup = false
    begin
      new_materials = CreateNewMaterialsStep.new(work_order, params_for_completion)
      success = DispatchService.new.process([
        CreateContainersStep.new(work_order, params_for_completion),
        new_materials,
        UpdateOldMaterialsStep.new(work_order, params_for_completion),
        LockSetStep.new(work_order, params_for_completion, new_materials),
        UpdateWorkOrderStep.new(work_order, params_for_completion),
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
      flash[:notice] = 'Your work order is updated'
    elsif cleanup
      flash[:error] = "The work order could not be updated"
    else
      flash[:error] = "There has been a problem with the work order update. Please contact support."
    end

    # SEND EMAIL
    return success
  end

  helper_method :work_order

end
