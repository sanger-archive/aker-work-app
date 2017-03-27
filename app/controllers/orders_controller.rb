class OrdersController < ApplicationController

  include Wicked::Wizard
  steps :set, :product, :cost, :proposal, :summary

  def show
    render_wizard
  end

  def update
    unless params[:work_order].nil?
      params[:work_order][:status] = step.to_s

      if work_order.update_attributes(work_order_params) && last_step?
        if work_order.product.suspended?
          flash[:notice] = "That product is suspended and cannot currently be ordered."
          render_wizard
          return
        end

        begin
          work_order.create_locked_set
        rescue => e
          logger.error "Failed to create locked set"
          logger.error e.backtrace
          flash[:error] = "The request to the set service failed."
          render_wizard
          return
        end

        begin
          work_order.send_to_lims
        rescue => e
          logger.error "Failed to send work order"
          logger.error e.backtrace
          flash[:error] = "The request to the LIMS failed."
          render_wizard
          return
        end

        work_order.update_attributes(status: 'active')
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
    SetClient::Set.all.select { |s| s.meta["size"] > 0 }
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
    return 0 if work_order.original_set_uuid.nil?
    return work_order.original_set.meta['size']
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
