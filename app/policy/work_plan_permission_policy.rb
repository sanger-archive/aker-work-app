# frozen_string_literal: true
class WorkPlanPermissionPolicy
  def initialize(user, work_plan)
    @user = user
    @work_plan = work_plan
  end

  # Everyone has :read and :create permission.
  # :write (or any other) permission includes:
  #   - the plans owner
  #   - the current user if their groups include the plans owner
  #   - the current user if the work plan is not in construction, and
  #     the current user has spend permission on the plans project
  def permitted?(access)
    %i[read create].include?(access) ||
      user.email == plans_owner ||
      user.groups.include?(plans_owner) ||
      !work_plan.in_construction? && can_modify_plan? ||
      false
  end

  private

  def user
    @user
  end

  def work_plan
    @work_plan
  end

  def plans_owner
    work_plan.owner_email
  end

  def can_modify_plan?
    Study.current_user_has_spend_permission_on_project?(work_plan.project_id)
  end
end
