module WorkOrder::Completion
  
  def process(msg, status)
    # 1 - Create containers
    MatconClient::Container.create(msg[:containers])

    # 2 - Create new materials
    new_materials = MatconClient::Material.create(msg[:new_materials])

    # 3 - Update old materials
    MatconClient::Material.update(msg[:updated_materials])

    # 4 - New locked set
    locked_set = SetService::Set.create(locked: true, materials: new_materials.map(&:uuid))

    # 5 - Update WorkOrder
    work_order.update_attributes!(status: status, comment: msg[:comment], set_id: locked_set)

    # 6 - Email
    notify_work_order_process(status)
  end

  def complete(msg)
    process(msg, 'completed')
  end

  def cancel(msg)
    process(msg, 'canceled')
  end

  def notify_work_order_process(status)
  end    
end