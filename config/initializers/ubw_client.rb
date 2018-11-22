require 'ubw_client'

Rails.application.config.after_initialize do
  Ubw::Client.site = Rails.application.config.ubw_service_url

  Ubw::Client.connection do |connection|
    connection.proxy {}
#    if Rails.env.production? || Rails.env.staging?
#      connection.use ZipkinTracer::FaradayHandler, 'UBW service'
#    end
  end
end
