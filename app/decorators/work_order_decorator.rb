class WorkOrderDecorator < Draper::Decorator
  include LinkableToSets

  delegate_all
  decorates_association :work_plan
  decorates_association :jobs
  decorates_finders

  # Links these attributes to Sets in the Set Service
  # See LinkableToSets for more
  link_to_set :set_uuid
end
