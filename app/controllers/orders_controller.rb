class OrdersController < ApplicationController

  include Wicked::Wizard

  steps :set, :proposal, :product, :cost, :summary

  def show
    authorize! :write, work_order

    render_wizard
  end

  def update
    authorize! :write, work_order
    begin
      perform_update_authorization!

      perform_update
    rescue CanCan::AccessDenied => e
      flash[:error] = e.message
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

  def get_all_proposals_spendable_by_current_user
    StudyClient::Node.where(cost_code: '!_none', spendable_by: [current_user.email] + current_user.groups).all.uniq {|p| p&.id}
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

  helper_method :work_order, :get_all_aker_sets, :proposal, :get_all_proposals_spendable_by_current_user, :get_current_catalogues, :item_option_selections, :last_step?, :first_step?

private

  def user_and_groups_list
    [current_user.email, current_user.groups].flatten
  end

  def stamp_client_authorize!(role, element_ids, user_and_groups)
    element_ids = [element_ids].flatten
    user_and_groups = [user_and_groups].flatten

    value = StampClient::Permission.check_catch({
      permission_type: role,
      names: user_and_groups,
      material_uuids: element_ids
    })
    raise AkerPermissionGem::NotAuthorized.new("Not authorised to perform '#{role}' with the materials [#{StampClient::Permission.unpermitted_uuids.join(',')}]") unless value
  end

  def perform_update_authorization!
    if step==:set
      if !params[:work_order].nil? && work_order_params[:original_set_uuid]
        original_set = SetClient::Set.find_with_materials(work_order_params[:original_set_uuid]).first
        check_materials = original_set.materials
        stamp_client_authorize!(:spend, check_materials.map(&:id), user_and_groups_list)
      end
    elsif step==:proposal
      unless params[:work_order].nil?
        StudyClient::Node.authorize! :spend, work_order_params[:proposal_id], user_and_groups_list
      end
    elsif step==:summary
      StudyClient::Node.authorize! :spend, proposal.id, [current_user.email, current_user.groups].flatten
      stamp_client_authorize!(:spend, work_order.materials.map(&:id), user_and_groups_list)
    end
  end

  def perform_update
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

  def nothing_to_update
    if params[:work_order].nil?
      return true
    else
      if step==:product
        # comment and desired date may have been updated, even though no project has been selected
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
