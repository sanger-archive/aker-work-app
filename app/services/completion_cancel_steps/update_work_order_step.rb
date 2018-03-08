class UpdateWorkOrderStep
	attr_reader :old_status, :old_close_comment
	def initialize(work_order, msg, finish_status)
		@finish_status = finish_status
		@work_order = work_order
		@msg = msg
	end

	# Step 4 - Update WorkOrder
	def up
		@old_status = @work_order.status
		@old_close_comment = @work_order.close_comment
		@work_order.update_attributes!(
			status: @finish_status.to_s == 'complete' ? WorkOrder.COMPLETED : WorkOrder.CANCELLED,
			close_comment: @msg[:work_order][:comment],
			completion_date: Date.today,
		)
	end

	def down
		@work_order.update_attributes!(status: old_status, close_comment: old_close_comment)
	end
end
