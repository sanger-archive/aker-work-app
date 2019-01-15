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

  def cost_code
    # Load the cost code only once, even if it's nil
    unless defined? @code_code
      @cost_code = work_order.work_plan.decorate.parent_cost_code
    end
    @cost_code
  end

  def work_order_can_be_dispatched
    if !work_order.can_be_dispatched?
      errors.add(:work_order, 'can not be dispatched')
    end
  end

  def modules_are_valid
    unless cost_code
      errors.add(:base, "No cost code is associated with this order's project.")
      return
    end
    bad_module_names = UbwClient::missing_unit_prices(work_order.process_modules.map(&:name).to_a, cost_code)
    unless bad_module_names.empty?
      errors.add(:base, "Process module could not be validated: #{bad_module_names}")
    end
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
    return true unless Rails.configuration.send_to_lims[:enabled]
    begin
      LimsClient.post(url, body)
    rescue StandardError => e
      errors.add(:base, e.message)
      return false
    end
    return true
  end
end

