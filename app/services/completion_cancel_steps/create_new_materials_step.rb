class CreateNewMaterialsStep

	attr_reader :materials

	def initialize(work_order, msg)
		@work_order = work_order
		@msg = msg
	end

	# 2 - Create new materials
	def up
		@materials =[]
		containers_to_save = []

		@msg[:work_order][:new_materials].each do |mat|
			container = mat[:container]
			mat.delete(:container)
			answer = MatconClient::Material.create(mat)
			if answer.class != MatconClient::Material
				answer = answer.to_a
			end
			new_material = [answer].flatten.first

	    	# Find the container and add the material to it
	    	container_instance = MatconClient::Container.where(barcode: container[:barcode]).to_a.first
	    	if container.has_key?(:address)
	    		container_instance.add_to_slot(container[:address], new_material)
	    	else
	    		container_instance.material_id = new_material.id
	    	end

	    	# Add the containers to save to a list to save them afterwards
	    	containers_to_save.push(container_instance)

	    	# Store the materials
	    	@materials.push(new_material)
		end
		containers_to_save.each do |c|
		  c.update_attributes(print_count: 0) if c.print_count.nil?
		end
		containers_to_save.each(&:save)

	end

	def down
	end
end