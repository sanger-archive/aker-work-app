class CreateContainersStep
  attr_reader :new_containers

  def initialize(work_order, msg)
    @work_order = work_order
    @msg = msg
  end

  def containers_to_create
    extra_fields = { print_count: 0 }
    @msg[:work_order][:containers].
      reject { |c| MatconClient::Container.where(barcode: c[:barcode]).first }.
      map { |c| c.merge(extra_fields) }
  end

  # 1 - Create containers
  def up
    @new_containers ||= []
    cc = containers_to_create
    unless cc.empty?
      results = MatconClient::Container.create(cc)
      if results.is_a? (MatconClient::Container)
        @new_containers = [results]
      else
        @new_containers += results.to_a
        while results.has_next?
          results = cc.next
          @new_containers += results.to_a
        end
      end
    end
  end

  def down
    # Iterate through the array, destroying the containers one by one,
    #  deleting each one from the array once it has been destroyed
    @new_containers.delete_if do |container|
      container.destroy()
      true
    end
  end
end
