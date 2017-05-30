class ContainerNotFound < StandardError
end

class CreateNewMaterialsStep


  attr_reader :materials

  def initialize(work_order, msg)
    @work_order = work_order
    @msg = msg
  end

  def get_container(barcode)
    @containers_by_barcode ||= {}
    @containers_by_barcode[barcode] ||= MatconClient::Container.where(barcode: barcode)
  end

  # Step 2 - Create new materials
  def up
    @materials =[]
    @modified_container_before_save = []
    containers_to_save = []

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
        container_instance = get_container(container[:barcode]).first
        raise ContainerNotFound unless container_instance
        @modified_container_before_save.push(container_instance)
        # if container has key address it is (hopefully) a plate so add material to the address
        if container.has_key?(:address)
          container_instance.add_to_slot(container[:address], new_material)
        else
        # container is a tube so add to the tube's slot
          container_instance.slots.first.material_id = new_material.id
        end

        # Add the containers_to_save to a list to save them afterwards
        containers_to_save.push(container_instance)
      end

      # Store the materials
      @materials.push(new_material)
    end
    containers_to_save.each(&:save)
  end

  def down
    @modified_container_before_save.uniq{|l| l.id}.each do |c|
      cont = MatconClient::Container.find(c.id)
      cont.update_attributes(c.serialize)
    end

    @materials.each do |m|
      MatconClient::Material.destroy(m.id)
    end
  end
end