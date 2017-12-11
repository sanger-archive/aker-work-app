require 'billing_facade_client'

Rails.application.config.after_initialize do
  BillingFacadeClient.site = Rails.application.config.billing_facade_url

  BillingFacadeClient.connection do |connection|
    ENV['HTTP_PROXY'] = nil
    ENV['http_proxy'] = nil
    ENV['https_proxy'] = nil
    connection.faraday.proxy ''
    if Rails.env.production? || Rails.env.staging?
      connection.use ZipkinTracer::FaradayHandler, 'BillingFacade service'
    end
  end
end
