class WorkPlanDecorator < Draper::Decorator
  include LinkableToSets
  include LinkableToProjects

  delegate_all
  decorates_association :work_orders
  decorates_finders

  link_to_set :original_set_uuid
  link_to_project :project_id
end