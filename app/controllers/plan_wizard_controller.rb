require 'data_release_strategy_client'

class PlanWizardController < ApplicationController
  include Wicked::Wizard

  steps :set, :project, :product, :data_release_strategy, :dispatch

  helper_method :work_plan, :get_my_sets, :project, :get_spendable_projects, :get_current_catalogues,
                :get_current_catalogues_with_products, :get_data_release_strategies, :last_step?, :first_step?

  def show
    authorize! :write, work_plan

    if step == :data_release_strategy && !work_plan.is_product_from_sequencescape?
      skip_step
    end

    if step==Wicked::FINISH_STEP
      jump_to(:dispatch)
    end
    render_wizard
  end

  def update
    authorize! :write, work_plan

    begin
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

  def get_data_release_strategies
    data_release_strategies = []
    begin
      data_release_strategies = DataReleaseStrategyClient.find_strategies_by_user(current_user.email)
    rescue Faraday::ConnectionFailed => e
      flash[:error] = "There is no connection with the Data release service."
    end
    data_release_strategies
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
    @work_plan.in_construction? && !params[:work_plan]
  end

  def perform_step
    return UpdatePlanService.new(work_plan_params, work_plan, params[:commit]=='dispatch', user_and_groups_list, flash).perform
  end

  def work_plan_params
    return {} unless params[:work_plan]
    params.require(:work_plan).permit(
      :original_set_uuid, :project_id, :product_id, :product_options, :comment, :priority, :data_release_strategy_id, :work_order_id, :work_order_modules, :work_order_module => {}
    )
  end

end
