class CreateNewMaterialsStep
	def initialize(work_order, msg)
		@work_order = work_order
		@msg = msg
	end

	# 2 - Create new materials
	def up
	    new_materials = MatconClient::Material.create(@msg[:work_order][:new_materials])
	end

	def down
	end
end