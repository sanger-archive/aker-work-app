# Class responsible for dispatching a Work Order to a LIMS
class WorkOrderDispatcher
  extend ActiveModel::Naming
  attr_reader :serializer, :policy, :errors
  attr_accessor :work_order

  def initialize(options = {})
    @serializer = options.fetch(:serializer, WorkOrderSerializer.new)
    @policy     = options.fetch(:policy, DispatchableWorkOrderPolicy.new)
    @errors     = ActiveModel::Errors.new(self)
  end

  def dispatch(work_order)
    @work_order = work_order.decorate
    return false if !valid?
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

  def valid?
    dispatchable = policy.dispatchable?(work_order)
    errors.merge!(policy.errors) if !dispatchable
    dispatchable
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

