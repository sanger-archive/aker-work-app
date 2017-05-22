class CreateNewMaterialsStep

	attr_reader :materials

	def initialize(work_order, msg)
		@work_order = work_order
		@msg = msg
	end

	# 2 - Create new materials
	def up
		@materials =[]
		debugger
		@msg[:work_order][:new_materials].each do |mat|
			container = mat[:container]
			mat.delete(:container)
			answer = MatconClient::Material.create(mat)
			if answer.class != MatconClient::Material
				answer = answer.to_a
			end
			new_materials = [answer].flatten

	    	# Find a container
	    	container_instance = MatconClient::Container.where(barcode: container[:barcode]).to_a.first
	    	if container.has_key?(:address)
	    		container_instance.add_materials(container[:address], new_materials)
	    	else
	    		container_instance.add_materials(new_materials)
	    	end
	    	# container.add_materials(new_materials)

	    	@materials.concat(new_materials)
		end

	end

	def down
	end
end