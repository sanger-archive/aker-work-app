class OrdersController < ApplicationController

  include Wicked::Wizard
  steps :set, :product, :cost, :proposal, :summary

  def show
    render_wizard
  end

  def update
    unless params[:work_order].nil?
      params[:work_order][:status] = step.to_s
      params[:work_order][:status] = 'active' if last_step?

      if work_order.update_attributes(work_order_params) && last_step?
        work_order.create_locked_set
        flash[:notice] = 'Your Work Order has been created'
      end
    end

    render_wizard work_order
  end

  protected

  def work_order
    @work_order ||= WorkOrder.find(params[:work_order_id])
  end

  def aker_set
    work_order.aker_set
  end

  def get_all_aker_sets
    SetClient::Set.all
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

  def get_set_size
    set_uuid = work_order.original_set_uuid
    return 0 if set_uuid.nil?
    SetClient::Set.find_with_materials(set_uuid).first.materials.length
  end

  def last_step?
    step == steps.last
  end

  def first_step?
    step == steps.first
  end

  helper_method :work_order, :aker_set, :get_all_aker_sets, :item, :proposal, :get_all_proposals, :get_current_catalogues, :get_set_size, :item_option_selections, :last_step?, :first_step?

  private

  def work_order_params
    params.require(:work_order).permit(
      :status, :original_set_uuid, :proposal_id, :product_id, :comment, :desired_date
    )
  end

end
