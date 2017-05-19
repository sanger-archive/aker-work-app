class UpdateWorkOrderStep
	def initialize(work_order, msg)
		@work_order = work_order
		@msg = msg
	end

	# 5 - Update WorkOrder
	def up
		work_order.update_attributes!(status: status, comment: @msg[:work_order][:comment])
	end

	def down
	end
end