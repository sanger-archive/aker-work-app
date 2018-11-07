class WorkPlanDecorator < Draper::Decorator
  include LinkableToSets
  include LinkableToProjects

  delegate_all
  decorates_association :work_orders
  decorates_finders

  link_to_set :original_set_uuid
  link_to_project :project_id

  def parent_cost_code
    return nil unless project_id
    parent_project_id = project&.parent_id
    return nil unless parent_project_id
    StudyClient::Node.find(parent_project_id).first&.cost_code
  end
end
