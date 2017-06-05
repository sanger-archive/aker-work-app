class OrdersController < ApplicationController

  include Wicked::Wizard

  steps :set, :product, :cost, :proposal, :summary

  def show
    authorize! :write, work_order

    render_wizard
  end

  def update
    authorize! :write, work_order

    if params[:work_order].nil? || perform_step
      render_wizard work_order
    else
      render_wizard
    end
  end

protected

  def work_order
    @work_order ||= WorkOrder.find(params[:work_order_id])
  end

  def get_all_aker_sets
    if user_signed_in?
      SetClient::Set.where(owner_id: current_user.email).all.select { |s| s.meta["size"] > 0 }
    else
      []
    end
  end

  def proposal
    work_order.proposal
  end

  def get_all_proposals
    StudyClient::Node.where(cost_code: '!_none').all
  end

  def get_current_catalogues
    Catalogue.where(current: true).all
  end

  def last_step?
    step == steps.last
  end

  def first_step?
    step == steps.first
  end

  helper_method :work_order, :get_all_aker_sets, :proposal, :get_all_proposals, :get_current_catalogues, :item_option_selections, :last_step?, :first_step?

private

  def perform_step
    return UpdateOrderService.new(work_order_params, work_order, flash).perform(step)
  end

  def work_order_params
    params.require(:work_order).permit(
      :status, :original_set_uuid, :proposal_id, :product_id, :comment, :desired_date
    )
  end

  def params_for_work_order_completion
    params.require(:work_order).permit(:work_order_id, :comment, :containers,
      :updated_materials => [],
      :new_materials => []
    )
  end

end
