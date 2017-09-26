class LockSetStep
  def initialize(work_order, msg, material_step)
    @work_order = work_order
    @msg = msg
    @material_step = material_step
  end

  # Step 5 - New finished locked set
  def up
    timestamp = Time.now.strftime("%H:%M:%S-%d/%m/%y")
    finished_set = SetClient::Set.create(name: "Work Order Completion #{@work_order.id} #{timestamp}")
    @work_order.update_attributes!(finished_set_uuid: finished_set.id)

    finished_set.set_materials(@material_step.materials.map(&:id))
    finished_set.update_attributes(owner_email: @work_order.owner_email, locked: true)
  end

  def down
    if @work_order.finished_set_uuid
      @work_order.update_attributes(finished_set_uuid: nil)
    end
  end
end
