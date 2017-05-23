class UpdateOldMaterialsStep
	def initialize(work_order, msg)
		@work_order = work_order
		@msg = msg
	end

	# 3 - Update old materials
	def up
		 # add owner id from the owner of the workorder in the request
		 @msg[:work_order][:updated_materials].map do |mat_obj|
		 	updated_params = mat_obj
		 	updated_params[:owner_id] = @work_order.user.email
		 	uuid = mat_obj[:material_id]
		 	mat_obj.delete(:material_id)
			MatconClient::Material.find(uuid).update_attributes(updated_params)
		 end
	end

	def down
	end
end