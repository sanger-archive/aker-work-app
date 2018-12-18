class ProcessModuleChoicesController < ApplicationController

  def update
    authorize! :write, work_plan
    service.perform
    redirect_to dispatch_path
  end

  private

  def work_plan
    @work_plan ||= WorkPlan.find(params[:work_plan_id])
  end

  def dispatch_path
    work_plan_build_path(work_plan_id: work_plan.id, id: :dispatch)
  end

  def service
    @service ||= ReviseOptionsService.new(work_plan, update_params[:process_id].to_i, process_modules, process_module_values, user_and_groups_list, flash)
  end

  def user_and_groups_list
    [current_user.email] + current_user.groups
  end

  def process_modules
    JSON.parse(update_params[:process_modules])
  end

  def process_module_values
    process_modules.map do | module_id |
      if update_params[:work_order_modules].nil? || update_params[:work_order_modules][module_id.to_s].nil?
        nil
      else
        update_params[:work_order_modules][module_id.to_s][:selected_value]
      end
    end
  end

  def update_params
    params.require(:work_plan).permit(:id, :process_id, :process_modules, work_order_modules: {})
  end

end