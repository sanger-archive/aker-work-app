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
      SetClient::Set.where(owner: current_user.email).all.select { |s| s.meta["size"] > 0 }
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
    params[:work_order][:status] = step.to_s

    wop = work_order_params

    if work_order.active?
      flash[:error] = "This work order has already been issued. No further action is possible."
      return false
    end

    selected_set_uuid = wop['original_set_uuid']

    if (selected_set_uuid && work_order.set_uuid &&
        selected_set_uuid!=work_order.original_set_uuid)
      logger.error "User tried to re-select set after locked set had been created"
      flash[:error] = ("The sample set for this work order has already been locked. " +
        " To order work for different samples, please start a new work order.")
      return false
    end

    if work_order.update_attributes(wop)
      if work_order.original_set_uuid && work_order.set_uuid.nil?
        begin
          work_order.create_locked_set
        rescue => e
          logger.error "Failed to create locked set"
          logger.error e.backtrace
          flash[:error] = "The request to the set service failed."
          return false
        end
        logger.debug "Created locked set"
      end

      if last_step?
        if work_order.product.suspended?
          flash[:notice] = "That product is suspended and cannot currently be ordered."
          return false
        end

        begin
          work_order.send_to_lims
        rescue => e
          logger.error "Failed to send work order"
          logger.error e.backtrace
          flash[:error] = "The request to the LIMS failed."
          return false
        end

        work_order.update_attributes(status: 'active')
        flash[:notice] = 'Your work order has been created'
      end

    end
    return true
  end

  def work_order_params
    params.require(:work_order).permit(
      :status, :original_set_uuid, :proposal_id, :product_id, :comment, :desired_date
    )
  end

end
