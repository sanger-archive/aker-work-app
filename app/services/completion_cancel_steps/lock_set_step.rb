class LockSetStep
  def initialize(job, msg, material_step)
    @job = job
    @msg = msg
    @material_step = material_step
  end

  # Step 5 - New finished locked set
  def up
    # We only want to create a completion set if any new materials are returned
    # We only want to create a completion set if the work order has been concluded
    work_order = @job.work_order
    return unless @material_step.materials.length.positive? && work_order.status==WorkOrder.CONCLUDED
    timestamp = Time.now.strftime('%y-%m-%d %H:%M:%S')
    finished_set = SetClient::Set.create(
      name: "Work Order #{work_order.id} Completion #{timestamp}"
    )
    work_order.update_attributes!(finished_set_uuid: finished_set.id)
    finished_set.set_materials(@material_step.materials.map(&:id))
    finished_set.update_attributes(owner_id: work_order.owner_email,
                                   locked: true)
    @next_order = work_order.next_order
    if @next_order
      @next_order.update_attributes!(original_set_uuid: finished_set.id)
    end
  end

  def down
    work_order = @job.work_order
    return unless work_order.finished_set_uuid
    next_order = work_order.next_order
    if next_order&.original_set_uuid==work_order.finished_set_uuid
      next_order.update_attributes!(original_set_uuid: nil)
    end
    work_order.update_attributes!(finished_set_uuid: nil)
  end
end
