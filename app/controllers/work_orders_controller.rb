require 'study_management_client'
class WorkOrdersController < ApplicationController

  before_action :work_order, only: [:show]

  def index
    @active_work_orders = WorkOrder.active
    @pending_work_orders = WorkOrder.pending
    @proposals = StudyManagementClient.get_nodes_with_cost_code
  end

  def new
    work_order = WorkOrder.create

    redirect_to work_order_build_path(
      id: Wicked::FIRST_STEP,
      work_order_id: work_order.id
    )
  end

  def destroy
    work_order.destroy
    flash[:notice] = "Work Order Cancelled"
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
