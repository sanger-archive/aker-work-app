class PlanWizardController < ApplicationController
  include Wicked::Wizard

  steps :product, :set, :project, :dispatch

  helper_method :work_order, :get_all_aker_sets, :project, :get_spendable_projects, :get_current_catalogues,
                :get_current_catalogues_with_products, :last_step?, :first_step?

  def show
    # TODO - work-plan write authorisation

    render_wizard
  end

  def update
    # TODO - work-plan write authorisation

    begin
      check_update_authorization!
      perform_update
    rescue CanCan::AccessDenied => e
      flash[:error] = e.message
      render_wizard
    end
  end

  def plan
    @plan ||= WorkPlan.find(params[:work_plan_id])
  end

  def get_my_sets
    SetClient::Set.where(owner_id: current_user.email, empty: false).order(created_at: :desc).all
  end

  def project
    plan&.project
  end

  def get_spendable_projects
    StudyClient::Node.where(
      node_type: 'subproject',
      with_parent_spendable_by: user_and_groups_list
    ).all.uniq { |proj| proj&.id }
  end

  def get_current_catalogues
    Catalogue.where(current: true).all
  end

  def get_current_catalogues_with_products
    # format for grouped_options_for_select form helper method in product.html.erb
    # include whether the product is not available i.e needs to be disabled, and initial blank option
    get_current_catalogues.map { |c| [c.pipeline, c.products.map { |p| [p.name, p.id, {'disabled'=>p.availability != 'available'}] } ] }.insert(0, ['', ['']])
  end

  def last_step?
    step == steps.last
  end

  def first_step?
    step == steps.first
  end

  def user_and_groups_list
    [current_user.email] + current_user.groups
  end

  def stamp_client_authorize!(role, element_ids, user_and_groups)
    element_ids = [element_ids].flatten
    user_and_groups = user_and_groups.flatten

    value = StampClient::Permission.check_catch({
      permission_type: role,
      names: user_and_groups,
      material_uuids: element_ids
    })
    unless value
      raise CanCan::AccessDenied.new(stamp_permission_error(role, StampClient::Permission.unpermitted_uuids))
    end
  end

  def stamp_permission_error(role, uuids)
    uuids = StampClient::Permission.unpermitted_uuids
    if uuids.length > 10
      joined = uuids[0,10].to_s +' (too many to list)'
    else
      joined = uuids.to_s
    end
    "Not authorised to perform '#{role}' with materials #{joined}."
  end

  def check_update_authorization!
    if step==:product
      # TODO
    elsif step==:set
      # TODO
    elsif step==:project
      # TODO
    elsif step==:dispatch
      # TODO
    end
  end

  def perform_update
    if nothing_to_update
      flash[:error] = "Please select an option to proceed"
      render_wizard
    elsif perform_step
      render_wizard plan
    else
      render_wizard
    end
  end

  def nothing_to_update
    return true unless params[:work_plan]
    if step==:product
      return params[:work_plan][:product_id].blank?
    end
    false
  end

  def perform_step
    # TODO perform the update
  end

  def plan_params
    params.require(:work_plan).permit(
      :original_set_uuid, :project_id, :product_id, :product_options, :comment, :desired_data
    )
  end
end
