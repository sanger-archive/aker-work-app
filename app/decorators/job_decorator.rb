class JobDecorator < Draper::Decorator
  include LinkableToSets
  include LinkableToContainers

  delegate_all
  decorates_association :work_order
  decorates_finders

  link_to_set :set_uuid, :input_set_uuid
  link_to_container :container_uuid

  # TODO: Get rid of this
  def materials?(uuids)
    return true if uuids.empty?
    return false if input_set_material_ids.empty?
    uuids.all? do |uuid|
      input_set_material_ids.include?(uuid)
    end
  end
end