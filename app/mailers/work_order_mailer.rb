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

  def dispatch_failed
    @work_order = params[:work_order]
    mail(
      to: @work_order.work_plan.owner_email,
      subject: I18n.t('work_order_mailer.dispatch_failed.subject', env: Rails.env, work_order_id: @work_order.id)
    )
  end

  def dispatched
    @work_order = params[:work_order]
    mail(
      to: @work_order.work_plan.owner_email,
      subject: I18n.t('work_order_mailer.dispatched.subject', env: Rails.env, work_order_id: @work_order.id)
    )
  end

private

  def akerdev(subject)
    email = (Rails.configuration.respond_to?(:akerdev_email) && Rails.configuration.akerdev_email)
    email ||= 'akerdev@sanger.ac.uk'
    mail(to: email, subject: subject)
  end

end
