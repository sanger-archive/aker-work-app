class UpdateWorkOrderStep
	def initialize(work_order, msg)
		@work_order = work_order
		@msg = msg
	end

	# 5 - Update WorkOrder
	def up
		@status = @work_order.status
		@comment = @work_order.comment
		@work_order.update_attributes!(status: @msg[:work_order][:status], comment: @msg[:work_order][:comment])
	end

	def down
		@work_order.update_attributes!(status: @status, comment: @comment)
	end
end