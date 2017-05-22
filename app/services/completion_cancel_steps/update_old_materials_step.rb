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
			MatconClient::Material.find(mat_obj[:id]).update_attributes(updated_params)
		 end
	end

	def down
	end
end