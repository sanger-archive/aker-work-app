class UpdateOldMaterialsStep

	def initialize(work_order, msg)
		@work_order = work_order
		@msg = msg
	end

	# 3 - Update old materials
	def up
		@materials_before_changes = []
		 # add owner id from the owner of the workorder in the request
		 @msg[:work_order][:updated_materials].each do |mat_obj|
		 	updated_params = mat_obj
		 	updated_params[:owner_id] = @work_order.user.email
		 	uuid = mat_obj[:material_id]
		 	mat_obj.delete(:material_id)
		 	material = MatconClient::Material.find(uuid)
			@materials_before_changes.push(material.clone)
			material.update_attributes(updated_params)
		 end
	end

	def down
		@materials_before_changes.each do |old_data|
			remote = MatconClient::Material.find(old_data.id)
			remote.update_attributes(old_data.serialize)
		end
	end
end