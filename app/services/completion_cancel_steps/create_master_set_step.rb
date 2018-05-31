class CreateMasterSetStep
  def initialize(job)
    @job = job
  end

  # Step 4 - Create a master set, with materials from each jobs set, belonging to the work order
  def up
    work_order = @job.work_order

    if work_order.concluded?
      work_order.jobs.reload

      all_jobs_set_uuids = work_order.jobs.map(&:set_uuid)

      all_jobs_material_uuids = all_jobs_set_uuids.map do |uuid|
        SetClient::Set.find_with_materials(uuid).first.materials.map(&:id)
      end.flatten

      master_set = SetClient::Set.create(
        name: "Work Order #{work_order.id} - Master Set"
      )

      master_set.set_materials(all_jobs_material_uuids)

      master_set.update_attributes(owner_id: work_order.owner_email,locked: true)

      work_order.update_attributes!(finished_set_uuid: master_set.id)

      next_order = work_order.next_order
      if next_order
        next_order.update_attributes!(original_set_uuid: master_set.id)
      end

    end
  end

  def down
    # next_order = work_order.next_order
    # if next_order&.original_set_uuid==work_order.finished_set_uuid
    #   next_order.update_attributes!(original_set_uuid: nil)
    # end
    # work_order.update_attributes!(finished_set_uuid: nil)
  end
end
