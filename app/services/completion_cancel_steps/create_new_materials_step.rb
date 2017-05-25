class CreateNewMaterialsStep

	def initialize(work_order, msg)
		@work_order = work_order
		@msg = msg
	end

	# 2 - Create new materials
	def up
		@materials =[]
		@modified_container_before_save = []
		containers_to_save = []

		@msg[:work_order][:new_materials].each do |mat|
			container = mat[:container]
			mat.delete(:container)
			# answer can either be an ResultSet or an array, if a ResultSet convert to an array
			# add owner of materials?
			debugger
			answer = MatconClient::Material.create(mat)
			if answer.class != MatconClient::Material
				answer = answer.to_a
			end
			new_material = [answer].flatten.first

	    	# Find the container and add the material to it
	    	container_instance = MatconClient::Container.where(barcode: container[:barcode]).to_a.first
	    	@modified_container_before_save.push(container_instance)
	    	# if container has key address it is a plate so add material to the address
	    	if container.has_key?(:address)
	    		container_instance.add_to_slot(container[:address], new_material)
	    	else
	    	# container is a tube so directly add material
	    		container_instance.material_id = new_material.id
	    	end

	    	# Add the containers_to_save to a list to save them afterwards
	    	containers_to_save.push(container_instance)

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