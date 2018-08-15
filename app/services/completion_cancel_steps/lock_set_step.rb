class LockSetStep

  attr_reader :job, :msg, :new_material_step, :updated_material_step
  attr_accessor :job_concluded_set, :locked

  def initialize(job, msg, new_material_step, updated_material_step)
    @job = job
    @msg = msg
    @new_material_step = new_material_step
    @updated_material_step = updated_material_step
  end

  # Step 5 - Create a locked set for a concluded job
  def up
    # We only want to create a completion set if any new materials, or updated materials are returned
    # We want to create a job completion set for every concluded job
    work_order = job.work_order

    return unless new_material_step.materials.length.positive? || updated_material_step.materials.length.positive?

    timestamp = Time.now.strftime('%y-%m-%d %H:%M:%S')

    job_concluded_set = SetClient::Set.create(
      name: "Job #{job.id} Concluded #{timestamp}"
    )

    job.update_attributes!(set_uuid: job_concluded_set.id)

    # Release the materials so they can be used by another work order
    set_materials_availability(true)

    new_mats = new_material_step.materials.map(&:id)
    updated_mats = updated_material_step.materials.map(&:id)

    unique_material_ids = Set.new(new_mats + updated_mats)

    job_concluded_set.set_materials(unique_material_ids)

    job_concluded_set.update_attributes(owner_id: work_order.work_plan.owner_email, locked: true)

  end

  def down
    return unless job.set_uuid
    set_materials_availability(false)
    job.update_attributes(set_uuid: nil)
  end

private

  def set_materials_availability(availability)
    job.input_set_material_ids.each do |material_id|
      MatconClient::Material.new(id: material_id).update_attributes(available: availability)
    end
  end
end
