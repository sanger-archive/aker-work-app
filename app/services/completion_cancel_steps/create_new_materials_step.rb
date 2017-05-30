class ContainerNotFound < StandardError
end

class CreateNewMaterialsStep


	attr_reader :materials, :modified_containers

  def initialize(work_order, msg)
    @work_order = work_order
    @msg = msg
  end

  def get_container(barcode)
    @containers_by_barcode ||= {}
    @containers_by_barcode[barcode] ||= MatconClient::Container.where(barcode: barcode).first
  end

  # Step 2 - Create new materials
  def up
    @materials =[]
    containers_to_save = []
    @container_previous_contents = {}
    @modified_containers = []

    @msg[:work_order][:new_materials].each do |mat|
      container = mat[:container]
      mat.delete(:container)
      mat[:owner_id] = @work_order.user.email
      new_material = MatconClient::Material.create(mat)
      # if result set or array, get the material from it
      if new_material.class != MatconClient::Material
        new_material = new_material.first
      end

      if container
        # Find the container and add the material to it
        container_instance = get_container(container[:barcode])
        raise ContainerNotFound unless container_instance

        # Find the slot to add the material into
        if container.has_key?(:address)
          slot = container_instance.slots.select{|s| s.address == container[:address]}.first
        else
          slot = container_instance.slots.first
        end
        raise "Slot not found in container" unless slot

        # Store the previous contents of the slot (hopefully nil) in case it has to be rolled back
        @container_previous_contents[container_instance.id] ||= {}
        @container_previous_contents[container_instance.id][slot.address] = slot.material_id

        # Add the containers_to_save to a list to save them afterwards.
        # Don't add the same container twice.
        containers_to_save.push(container_instance) unless containers_to_save.include?(container_instance)
      end

      # Store the materials
      @materials.push(new_material)
    end

    containers_to_save.each do |c|
      c.save
      # This container has now been altered, so add it to the list for rollbacks
      @modified_containers.push(c.id)
    end
  end

  def down
    modified_containers.each do |cont_id|
      cont = MatconClient::Container.find(cont_id)
      if @container_previous_contents
        @container_previous_contents[cont_id].each do |address, material_id|
          slot = cont.slots.select{|s| s.address == address}.first
          slot.material_id = material_id
        end
      end
      cont.save
    end

    materials.each do |m|
      MatconClient::Material.destroy(m.id)
    end
  end
end