class WorkOrderMailer < ApplicationMailer

	def broker_not_connected
    mail(to: 'akerdev@sanger.ac.uk', subject: "RabbitMQ broker not connected.")
	end

end
