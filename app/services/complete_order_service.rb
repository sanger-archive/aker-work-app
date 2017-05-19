class CompleteOrderService

  def validate_work_order_completion_msg(schema, hash)
    
  end

  def self.process(params)
    # Validate Word Order exists
    work_order = WorkOrder.find(params[:work_order_id])

    # Validate against Work Order Completion
    WorkOrderCompletionValidator.validate(request)

    # Validate Materials were in original Work Order
    unless work_order[:updated_materials].empty?
      state = SetClient::Set.find_with_materials(work_order.set_uuid).first.materials.all? do |material|
        work_order[:updated_materials].map(&:uuid).include?(material.uuid)
      end
    end
  end
end