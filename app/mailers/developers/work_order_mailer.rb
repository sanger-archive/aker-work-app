# Sends emails about Work Orders to aker devs
class Developers::WorkOrderMailer < ApplicationMailer
  default to: Rails.configuration.akerdev_email

  def dispatch_failed
    @que_job    = params[:que_job]
    @work_order = params[:work_order]
    @exception  = params[:exception]

    mail(
      subject: I18n.t(
                'developers.work_order_mailer.dispatch_failed.subject',
                env: Rails.env,
                work_order_id: @work_order.id
              )
    )
  end
end
