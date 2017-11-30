class WorkOrderMailer < ApplicationMailer

	def message_queue_error(work_order, exception)
		@work_order = work_order
		@exception = exception
		status = work_order.status == 'active' ? 'submitted' : work_order.status
    mail(to: 'akerdev@sanger.ac.uk', subject: "Message failed to be added to the queue for Work Order #{work_order.id} #{status} event.")
	end

end
