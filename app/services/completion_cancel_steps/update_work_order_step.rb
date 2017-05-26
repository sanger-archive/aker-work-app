class UpdateWorkOrderStep
	def initialize(work_order, msg, finish_status)
		@finish_status = finish_status
		@work_order = work_order
		@msg = msg
	end

	# Step 4 - Update WorkOrder
	def up
		@status = @work_order.status
		@comment = @work_order.comment
		@work_order.update_attributes!(
			status: @finish_status == 'complete' ? WorkOrder.COMPLETED : WorkOrder.CANCELLED,
			comment: @msg[:work_order][:comment]
		)
	end

	def down
		@work_order.update_attributes!(status: @status, comment: @comment)
	end
end