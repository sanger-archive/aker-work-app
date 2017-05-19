class UpdateOldMaterialsStep
	def initialize(work_order, msg)
		@work_order = work_order
		@msg = msg
	end

	# 3 - Update old materials
	def up
    	MatconClient::Material.update(@msg[:work_order][:updated_materials])
	end

	def down
	end
end