class OrdersController < ApplicationController

  include Wicked::Wizard

  steps :set, :proposal, :product, :cost, :summary

  def show
    authorize! :write, work_order

    render_wizard
  end

  def update
    authorize! :write, work_order

    if nothing_to_update
      if step==:cost
        render_wizard work_order
        return
      end
      show_flash_error
    else
      if perform_step
        render_wizard work_order
      else
        render_wizard
      end
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

  def nothing_to_update
    if params[:work_order].nil?
      return true
    else
      if step==:product
        return params[:work_order][:product_id].nil?
      end
      return false
    end
  end

  def show_flash_error
    if step==:set
      flash[:error] = "Please select a set to proceed."
    end
    if step==:proposal
      flash[:error] = "Please select a proposal to proceed."
    end
    if step==:product
      flash[:error] = "Please select a product to proceed."
    end
    render_wizard
  end

  def perform_step
    return UpdateOrderService.new(work_order_params, work_order, flash).perform(step)
  end

  def work_order_params
    params.require(:work_order).permit(
      :status, :original_set_uuid, :proposal_id, :product_id, :comment, :desired_date
    )
  end

end
