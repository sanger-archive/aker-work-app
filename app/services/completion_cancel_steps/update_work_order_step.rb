class UpdateWorkOrderStep
	attr_reader :old_status
	def initialize(job)
		@job = job
	end

	# Step 4 - Update WorkOrder
	def up
		work_order = @job.work_order
		unless work_order.active?
			raise "The work order is not active."
		end
		@old_status = work_order.status

		all_jobs_concluded = work_order.jobs.all?{ |j| j.completed? || j.cancelled? }

		if all_jobs_concluded
			work_order.update_attributes!(
				status: WorkOrder.CONCLUDED,
				completion_date: Time.now
			)
		end
	end

	def down
		if old_status
			@job.work_order.update_attributes!(status: old_status, completion_date: nil)
		end
	end
end
