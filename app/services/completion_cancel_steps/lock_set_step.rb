class LockSetStep
	def initialize(work_order, msg, new_materials)
		@work_order = work_order
		@msg = msg
		@new_materials = new_materials
	end

	# Step 4 - New locked set
	def up
    	locked_set = SetService::Set.create(locked: true, materials: @new_materials.map(&:uuid))
    	work_order.update_attributes!(set_id: locked_set)
	end

	def down
	end
end