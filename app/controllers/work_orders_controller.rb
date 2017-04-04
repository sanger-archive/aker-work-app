class WorkOrdersController < ApplicationController

  before_action :authenticate_user!

  before_action :work_order, only: [:show]

  def index
    if user_signed_in?
      @active_work_orders = WorkOrder.active.for_user(current_user)
      @pending_work_orders = WorkOrder.pending.for_user(current_user)
    else
      @active_work_orders = []
      @pending_work_orders = []
    end
  end

  def new
    work_order = WorkOrder.create!(user: current_user)

    redirect_to work_order_build_path(
      id: Wicked::FIRST_STEP,
      work_order_id: work_order.id
    )
  end

  def destroy
    if work_order.active?
      flash[:error] = "This work order has already been issued, and cannot be cancelled."
    else
      work_order.destroy
      flash[:notice] = "Work order cancelled"
    end
    redirect_to work_orders_path
  end

  def show
  end

private

  def work_order
    @work_order ||= WorkOrder.find(params[:id])
  end

  helper_method :work_order

end
