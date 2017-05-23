class WorkOrderValidatorService
  attr_reader :work_order, :msg, :errors

  def initialize(work_order, msg)
    @work_order = work_order
    @msg = msg
    @errors = {}
  end

  def validate?
    [
      :correct_status?,                    # 0 - WO status
      :json_schema_valid?,                 # 1 - JSON Schema
      :work_order_exists?,                 # 2 - Validate Word Order exists
      :work_order_has_updated_materials?,  # 3 - Validate materials are in the original work order
      :containers_has_no_changes?          # 4 - Validate containers has no changes
    ].all? {|m| send(m) }
  end

  private
  def correct_status?
    return true if @work_order.status == 'active'
    error_return(422, 'The work order status should be active')
  end

  def json_schema_valid?
    list = JSON::Validator.fully_validate(schema_url, @msg)
    return true if list.length == 0
    error_return(422, "The work order does not comply with the schema at #{schema_url} because: #{list.join(',')}")
  end

  def work_order_exists?
    # 2 - Validate Word Order exists
    work_order = WorkOrder.find_by(id: @msg[:work_order][:work_order_id])
    return true if work_order == @work_order
    error_return(404, "The work order #{@msg[:work_order][:work_order_id]} does not exists")
  end

  def work_order_has_updated_materials?
    return true if work_order.has_materials?(@msg[:work_order][:updated_materials].pluck(:material_id))
    error_return(422, "The updated materials don't belong to this work order")
  end

  def containers_has_no_changes?
    return true if !containers_has_changed?(@msg[:work_order][:containers].pluck(:_id))
    error_return(422, "Some of the containers provided have a different content in the container service")
  end

  def schema_url
    Rails.configuration.work_order_completion_json_schema_path.to_s
  end

  def error_return(status, msg)
    @errors[:status] = status
    @errors[:msg] = msg
    false
  end

  def containers_has_changed?(containers)
    updated_containers = @msg[:work_order][:containers].select{|c| c.has_key?(:_id)}
    updated_containers.any? do |json_container|
      remote = MatconClient::Container.find(json_container[:_id])
      json_container.keys.any? do |attr_key|
        json_container[attr_key] != remote.send(attr_key)
      end
    end
    # get uid from json for the containers
    # find container from mac con client
    # for each other check json data = service data
    # if different return true

  end

end




