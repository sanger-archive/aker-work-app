class CreateMasterSetStep
  attr_reader :job
  attr_accessor :master_set

  def initialize(job)
    @job = job
  end

  # Step 4 - Create a master set, with materials from each jobs set, belonging to the work order
  def up
    work_order = @job.work_order

    # Wraps the block in a transaction, reloads (including associations), and locks the row.
    # If another request comes in at the same time it has to wait.
    #
    # See https://api.rubyonrails.org/classes/ActiveRecord/Locking/Pessimistic.html for details
    work_order.with_lock do
      return unless work_order.concluded? && work_order.finished_set_uuid.nil?

      all_jobs_set_uuids = work_order.jobs.map(&:set_uuid).compact

      all_jobs_material_uuids = all_jobs_set_uuids.map do |uuid|
        SetClient::Set.find_with_materials(uuid).first.materials.map(&:id)
      end.flatten

      self.master_set = SetClient::Set.create(
        name: "Work Order #{work_order.id} - Master Set"
      )

      master_set.set_materials(all_jobs_material_uuids)

      work_order.update_attributes!(finished_set_uuid: master_set.id)

      next_order = work_order.next_order
      if next_order
        next_order.update_attributes!(original_set_uuid: master_set.id)
      end

      # Do this last as can't be undone
      master_set.update_attributes(owner_id: work_order.owner_email,locked: true)
    end
  end

  def down
    work_order = job.work_order
    next_order = work_order.next_order
    if next_order && next_order&.original_set_uuid==work_order.finished_set_uuid
      next_order.update_attributes!(original_set_uuid: nil)
    end
    work_order.update_attributes!(finished_set_uuid: nil)

    if master_set && !master_set.locked
      if master_set.destroy == false
        Rails.logger.error <<~MESSAGE
          Tried to destroy Set #{master_set.name} but couldn't. Work Order #{work_order.id} may not be able to conclude.
        MESSAGE
      end
    end
  end
end
