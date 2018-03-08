class PlanWizardController < ApplicationController
  include Wicked::Wizard

  steps :set, :project, :product, :dispatch

  helper_method :work_plan, :get_my_sets, :project, :get_spendable_projects, :get_current_catalogues,
                :get_current_catalogues_with_products, :last_step?, :first_step?

  def show
    authorize! :write, work_plan
    if step==Wicked::FINISH_STEP
      jump_to(:dispatch)
    end
    render_wizard
  end

  def update
    authorize! :write, work_plan

    begin
      check_update_authorization!
      perform_update
    rescue CanCan::AccessDenied => e
      flash[:error] = e.message
      render_wizard
    end
  end

  def work_plan
    @work_plan ||= WorkPlan.find(params[:work_plan_id])
  end

  def get_my_sets
    SetClient::Set.where(owner_id: current_user.email, empty: false).order(created_at: :desc).all
  end

  def project
    work_plan&.project
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
    get_current_catalogues.map { |c| [c.pipeline, c.products.map { |p| [p.name, p.id, {'disabled'=> p.suspended? }] } ] }.insert(0, ['', ['']])
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
    if step==:set
      if params[:work_plan] && work_plan_params[:original_set_uuid]
        original_set = SetClient::Set.find_with_materials(work_plan_params[:original_set_uuid]).first
        check_materials = original_set.materials
        stamp_client_authorize!(:consume, check_materials.map(&:id), user_and_groups_list)
      end
    elsif step==:project
      # TODO
    elsif step==:product
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
      render_wizard work_plan
    else
      render_wizard
    end
  end

  def nothing_to_update
    !params[:work_plan]
  end

  def perform_step
    return UpdatePlanService.new(work_plan_params, work_plan, params[:commit]=='dispatch', flash).perform
  end

  def work_plan_params
    params.require(:work_plan).permit(
      :original_set_uuid, :project_id, :product_id, :product_options, :comment, :desired_date, :work_order_id, :work_order_modules
    )
  end

end
