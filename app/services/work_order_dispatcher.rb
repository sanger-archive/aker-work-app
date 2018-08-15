class WorkOrderDispatcher
  include ActiveModel::Validations

  attr_reader :serializer, :materials
  attr_accessor :work_order

  validate :work_order_can_be_dispatched
  validate :modules_are_valid
  validate :materials_are_available
  validate :work_order_has_jobs

  def initialize(options)
    @serializer = options.fetch(:serializer)
  end

  def dispatch(work_order)
    @work_order = work_order.decorate
    return false if invalid?
    set_materials_availability(false)
    serialized_work_order = serializer.serialize(work_order)

    if send_to_lims(job_creation_url, serialized_work_order)
      work_order.update_attributes!(status: 'active', dispatch_date: Time.now)
      return true
    else
      set_materials_availability(true)
      return false
    end
  end

private

  def work_order_can_be_dispatched
    if !work_order.can_be_dispatched?
      errors.add(:work_order, 'can not be dispatched')
    end
  end

  def modules_are_valid
    bad_modules = work_order.process_modules.reject { |m| validate_module_name(m.name) }
    unless bad_modules.empty?
      errors.add(:base, "Process module could not be validated: #{bad_modules.map(&:name).join(', ')}")
    end
  end

  def validate_module_name(module_name)
    uri_module_name = module_name.gsub(' ', '_').downcase
    BillingFacadeClient.validate_process_module_name(uri_module_name)
  end

  def materials_are_available
    if materials.any? { |material| material.available == false }
      errors.add(:materials, 'are not all available')
    end
  end

  def materials
    work_order.set_full_materials
  end

  def work_order_has_jobs
    if work_order.jobs.size == 0
      errors.add(:work_order, 'does not have any Jobs')
    end
  end

  def set_materials_availability(availability)
    work_order.set_material_ids.each do |material_id|
      MatconClient::Material.new(id: material_id).update_attributes(available: availability)
    end
  end

  def job_creation_url
    work_order.work_plan.product.catalogue.job_creation_url
  end

  def send_to_lims(url, body)
    begin
      LimsClient.post(url, body)
    rescue StandardError => e
      errors.add(:base, e.message)
      return false
    end
    return true
  end
end

