# Class to handle dispatching a selection of jobs to the next process in their work plan
class DispatchNextOrderService

  def initialize(job_ids, user_and_groups, messages)
    @job_ids = job_ids
    @user_and_groups = user_and_groups
    @messages = messages
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

  def helper
    @helper ||= PlanHelper.new(plan, @user_and_groups, @messages)
  end

  def new_process
    @new_process ||= begin
      procs = product.processes
      procs[procs.index(old_process) + 1]
    end
  end

  def combined_set
    @combined_set ||= begin
      set_uuids = jobs.map { |job| job.revised_output_set_uuid || job.output_set_uuid }
      material_uuids = set_uuids.flat_map { |setid| helper.set_material_ids(setid) }.uniq

      new_set = SetClient::Set.create(name: "Work Order #{@order.id}")
      new_set.set_materials(material_uuids)

      new_set
    end
  end

  def new_order_index
    # Not sure what the use is of order_index any more.
    # For now, just increment order_index for each new order added.
    plan.work_orders.map(&:order_index).max + 1
  end

  def validate
    return error("No job IDs supplied.") if @job_ids.empty?
    return error("Job IDs are from different work plans.") unless jobs.all? { |job| job.work_order.work_plan==plan }
    return error("Job IDS are from different processes.") unless jobs.all? { |job| job.work_order.process==old_process }
    return error("This is the last process in the product.") if old_process==product.processes.last
    return error("Jobs that have already been forwarded to the next process cannot be forwarded again.") if jobs.any? { |job| job.forwarded }
    return error("This plan is in a broken state.") if plan.broken?
    return false unless helper.check_broker
    validate_sets
  end

  def validate_sets
    jobs.each do |job|
      return error("Job #{job.id} has no output set.") unless job.output_set_uuid

      if job.revised_output_set_uuid
        return error("Job #{job.id} has no materials in its revised output set.") if set_empty(job.revised_output_set)
        return error("Job #{job.id} has extraneous materials in its revised output set.") unless is_subset_uuid(job.revised_output_set_uuid, job.output_set_uuid)
      else
        return error("Job #{job.id} has no materials in its output set.") if set_empty(job.output_set)
      end
    end
    true
  end

  def finalise_revised_sets
    jobs.each do |job|
      next unless job.revised_output_set_uuid
      set = job.revised_output_set
      if !set.locked && !set.update_attributes(locked: true)
        raise "Failed to lock set #{set.name}"
      end
    end
  end

  def execute
    result = false
    ActiveRecord::Base.transaction do
      result = execute_inner
      raise ActiveRecord::Rollback if not result
    end
    result
  end

private

  # This method should be called inside a transaction
  def execute_inner
    return false unless validate

    finalise_revised_sets

    now = Time.now
    jobs.each { |job| job.update_attributes!(forwarded: now) }

    @order = WorkOrder.create!(process: new_process, order_index: new_order_index,
                               work_plan: plan, status: WorkOrder.QUEUED)

    @order.update_attributes!(set_uuid: combined_set.uuid)

    plan.modules_for_process_id(new_process.id).each do |choice|
      WorkOrderModuleChoice.create!(work_order_id: @order.id, aker_process_modules_id: choice.aker_process_module_id,
                                    position: choice.position, selected_value: choice.selected_value)
    end

    unless work_order_splitter.split(@order)
      raise "The material set for the new work order could not be split."
    end

    unless work_order_dispatcher.dispatch(@order)
      Rails.logger.error "Failed to send work order"
      Rails.logger.error work_order_dispatcher.errors.full_messages
      raise "The request to the LIMS failed."
    end

    # Do this last because it cannot be undone
    combined_set.update_attributes(owner_id: @order.owner_email, locked: true)
    
    @order.reload.generate_dispatched_event(jobs)

    true
  end

  def set_empty(set)
    return set.meta[:size]==0
  end

  def is_subset_uuid(subset_uuid, superset_uuid)
    subset_materials = helper.set_material_ids(subset_uuid)
    superset_materials = helper.set_material_ids(superset_uuid)
    return (subset_materials - superset_materials).empty?
  end

  def work_order_dispatcher
    @dispatcher ||= WorkOrderDispatcher.new(serializer: WorkOrderSerializer.new)
  end

  def work_order_splitter
    @splitter ||= WorkOrderSplitter::ByContainer.new
  end

  def error(message)
    @messages[:error] = message
    return false
  end
end
