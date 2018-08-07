class JobDecorator < Draper::Decorator
  include LinkableToSets
  include LinkableToContainers

  delegate_all
  decorates_association :work_order
  decorates_finders

  link_to_set :set_uuid, :input_set_uuid
  link_to_container :container_uuid
end