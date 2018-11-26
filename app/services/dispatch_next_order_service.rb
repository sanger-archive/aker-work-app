# Class to handle dispatching a selection of jobs to the next process in their work plan
class DispatchNextOrderService

  def initialize(job_ids)
    @job_ids = job_ids
  end

  # DECORATED jobs from the @job_ids
  def jobs
    @jobs ||= @job_ids.map { |id| Job.find(id).decorate }
  end

  def plan
    @plan ||= jobs.first.work_order.work_plan
  end

  def product
    @product ||= plan.product
  end

  def old_process
    @old_process ||= jobs.first.work_order.process
  end

  def new_process
    @new_process ||= begin
      procs = product.processes
      procs[procs.index(old_process) + 1]
    end
  end

  def validate!
    raise "No job IDs supplied." if @job_ids.empty?
    raise "Job IDs are from different work plans." unless jobs.all { |job| job.work_order.work_plan==plan }
    raise "Job IDS are from different processes." unless jobs.all { |job| job.work_order.process==old_process }
    raise "This is the last process in the product." if old_process==product.processes.last
    raise "Jobs that have already been forwarded to the next process cannot be forwarded again." if jobs.any? { |job| job.forwarded }
    raise "This plan is in a broken state." if plan.broken?
    validate_sets!
  end

  def validate_sets!
    jobs.each do |job|
      raise "Job #{job.id} has no output set." unless job.output_set_uuid
      if job.revised_output_set_uuid && !is_subset(job.revised_output_set_uuid, job.output_set_uuid)
        raise "Job #{job.id} has extraneous materials in its revised output set."
      end
      if job.revised_output_set_uuid
        raise "Job #{job.id} has no materials in its revised output set." if set_empty(job.revised_output_set)
        raise "Job #{job.id} has extraneous materials in its revised output set." unless is_subset_uuid(job.revised_output_set_uuid, job.output_set_uuid)
      else
        raise "Job #{job.id} has no materials in its output set." if set_empty(job.output_set)
      end
    end
  end

  def finalise_revised_sets
    jobs.each do |job|
      next unless job.revised_output_set_uuid
      set = job.revised_output_set
      next if set.locked
      if !set.update_attributes(locked: true)
        raise "Failed to lock set #{set.name}"
      end
    end
  end

  def execute
    validate!

    finalise_revised_sets
    # Make work order
    # Make jobs
    # Dispatch
  end

private

  def set_empty(set)
    return set.meta[:size]==0
  end

  def set_material_ids(set_uuid)
    SetClient::Set.find_with_materials(set_uuid).first.materials.map(&:id)
  end

  def is_subset_uuid(subset_uuid, superset_uuid)
    subset_materials = set_material_ids(subset_uuid)
    superset_materials = set_material_ids(superset_uuid)
    return (subset_materials - superset_materials).empty?
  end
end
