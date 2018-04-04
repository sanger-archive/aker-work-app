class UpdateWorkOrderStep
	attr_reader :old_status, :old_close_comment
	def initialize(job, msg)
		@job = job
		@msg = msg
	end

	# Step 4 - Update WorkOrder
	def up
		@old_status = @job.work_order.status
		@old_close_comment = @job.work_order.close_comment

		all_jobs_concluded = @job.work_order.jobs.all?{ |j| j.completed? || j.cancelled? }

		if all_jobs_concluded
			@job.work_order.update_attributes!(
				status: WorkOrder.CONCLUDED,
				close_comment: @msg[:job][:comment],
				completion_date: Date.today,
			)
		end
	end

	def down
		@job.work_order.update_attributes!(status: old_status, close_comment: old_close_comment)
	end
end
