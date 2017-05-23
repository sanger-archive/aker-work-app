class LockSetStep
	def initialize(work_order, msg, material_step)
		@work_order = work_order
		@msg = msg
		@material_step = material_step
	end

	# Step 4 - New locked set
	def up
		timestamp = Time.now.strftime("%H:%M:%S-%d/%m/%y")
		set = SetClient::Set.create(name: "Work Order Completion #{@work_order.id} #{timestamp}", owner_id: @work_order.user.email)
		@work_order.update_attributes!(set_uuid: set.id)

		set.set_materials(@material_step.materials.map(&:id))
		set.update_attributes(locked: true)
	end

	def down
	end
end