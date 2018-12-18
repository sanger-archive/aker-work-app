class PlanWizardController < ApplicationController
  include Wicked::Wizard

  steps :set, :project, :product, :data_release_strategy, :dispatch

  helper_method :work_plan, :view_model, :last_step?, :first_step?

  before_action :revised_output, only: [:show]

  def show
    authorize! :write, work_plan
    skip_step if step == :data_release_strategy && !work_plan.is_product_from_sequencescape?
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

  private

  def work_plan
    return @work_plan if @work_plan
    @work_plan = WorkPlan

    case step
    when :dispatch
      @work_plan.includes(
        :data_release_strategy,
        :process_module_choices,
        work_orders: [:jobs],
        product: [{
          product_processes: {
            aker_process: :process_modules
          }
        }]
      )
    end
    @work_plan = @work_plan.find(params[:work_plan_id]).decorate
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
    if nothing_to_update?
      flash[:error] = "Please select an option to proceed"
      render_wizard
    elsif perform_step
      render_wizard work_plan
    else
      render_wizard
    end
  end

  def nothing_to_update?
    work_plan.in_construction? && !params[:work_plan]
  end

  def perform_step
    PlanUpdateService.new(work_plan_params, work_plan, user_and_groups_list, flash).perform
  end

  def work_plan_params
    return {} unless params[:work_plan]
    params.require(:work_plan).permit(
      :original_set_uuid, :project_id, :product_id, :product_options, :comment, :priority, :data_release_strategy_id, :work_order_id, :work_order_modules => {}
    )
  end

  def view_model
    @view_model ||= case step
      when :set
        ViewModels::WorkPlanSet.new(work_plan: work_plan, user: current_user)
      when :project
        ViewModels::WorkPlanProject.new(work_plan: work_plan, user: current_user)
      when :product
        ViewModels::WorkPlanProduct.new(work_plan: work_plan)
      when :data_release_strategy
        ViewModels::WorkPlanDRS.new(work_plan: work_plan, user: current_user)
      when :dispatch
        ViewModels::WorkPlanDispatch.new(work_plan: work_plan)
      end
  end

  def revised_output
    @job = Job.find(params[:revised_output]).decorate if params[:revised_output]
  end

end
