class JobDecorator < Draper::Decorator
  include LinkableToSets
  include LinkableToContainers

  delegate_all
  decorates_association :work_order
  decorates_finders

  link_to_set :input_set_uuid, :output_set_uuid, :revised_output_set_uuid
  link_to_container :container_uuid

  # TODO: Get rid of this
  def materials?(uuids)
    return true if uuids.empty?
    return false if input_set_material_ids.empty?
    uuids.all? do |uuid|
      input_set_material_ids.include?(uuid)
    end
  end

  def create_editable_set
    raise "Job already has a revised output set" if revised_output_set_uuid
    raise "Job has no output set" unless output_set_uuid
    self.revised_output_set = output_set.create_unlocked_clone("Job #{id} revised output")
    save!
    self.revised_output_set
  end

end
