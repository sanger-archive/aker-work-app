class WorkOrderMailer < ApplicationMailer

  def broker_not_connected
    akerdev("RabbitMQ broker not connected on #{ Rails.env }")
  end

  def broker_unconfirmed
    akerdev("Unconfirmed messages on RabbitMQ on #{ Rails.env }")
  end

  def broker_reconnected
    akerdev("RabbitMQ seems to have recovered on #{ Rails.env }")
  end

private

  def akerdev(subject)
    email = (Rails.configuration.respond_to?(:akerdev_email) && Rails.configuration.akerdev_email)
    email ||= 'akerdev@sanger.ac.uk'
    mail(to: email, subject: subject)
  end

end
