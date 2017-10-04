class OrdersController < ApplicationController

  include Wicked::Wizard

  steps :set, :proposal, :product, :summary

  # SSO
  before_action :check_user_signed_in

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

  # redirect path to workorders#index
  def finish_wizard_path
    work_orders_path
  end

  protected

    def work_order
      @work_order ||= WorkOrder.find(params[:work_order_id])
    end

    def get_all_aker_sets
      SetClient::Set.where(owner_id: current_user.email).order(created_at: :desc).all.select { |s| s.meta["size"] > 0 }
    end

    def proposal
      work_order.proposal
    end

    def get_all_proposals_spendable_by_current_user
      StudyClient::Node.where(cost_code: '!_none', spendable_by: [current_user.email] + current_user.groups).all.uniq {|p| p&.id}
    end

    def get_current_catalogues_with_products
      # format for grouped_options_for_select form helper method in product.html.erb
      # include whether the product is not available i.e needs to be disabled, and initial blank option
      get_current_catalogues.map{ |c| [c.pipeline, c.products.map{ |p| [p.name, p.id, {'disabled'=>p.availability != 'available'}] } ] }.insert(0, ['', ['']])
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

    helper_method :work_order, :get_all_aker_sets, :proposal, :get_all_proposals_spendable_by_current_user, :get_current_catalogues, :get_current_catalogues_with_products, :item_option_selections, :last_step?, :first_step?

  private

    def check_user_signed_in
      redirect_to Rails.configuration.login_url unless current_user
    end

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
      raise CanCan::AccessDenied.new(stamp_permission_error(role, StampClient::Permission.unpermitted_uuids)) unless value
    end

    def stamp_permission_error(role, uuids)
      uuids = StampClient::Permission.unpermitted_uuids
      if uuids.length > 20
        joined = uuids[0,20].to_s+' (too many to list)'
      else
        joined = uuids.to_s
      end
      "Not authorised to perform '#{role}' with the materials #{joined}"
    end

    def perform_update_authorization!
      if step==:set
        if !params[:work_order].nil? && work_order_params[:original_set_uuid]
          original_set = SetClient::Set.find_with_materials(work_order_params[:original_set_uuid]).first
          check_materials = original_set.materials
          stamp_client_authorize!(:consume, check_materials.map(&:id), user_and_groups_list)
        end
      elsif step==:proposal
        unless params[:work_order].nil?
          StudyClient::Node.authorize! :spend, work_order_params[:proposal_id], user_and_groups_list
        end
      elsif step==:summary
        StudyClient::Node.authorize! :spend, proposal.id, [current_user.email, current_user.groups].flatten
        stamp_client_authorize!(:consume, work_order.materials.map(&:id), user_and_groups_list)
      end
    end

    def perform_update
      if nothing_to_update
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
          return params[:work_order][:product_id].blank?
        end
        return false
      end
    end

    def show_flash_error
      flash[:error] = "Please select a #{step} to proceed."
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
