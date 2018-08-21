require 'jwt_serializer'

Rails.application.config.after_initialize do
  SetClient::Base.site = Rails.application.config.set_url

  SetClient::Base.connection do |connection|
    ENV['HTTP_PROXY'] = nil
    ENV['http_proxy'] = nil
    ENV['https_proxy'] = nil
    connection.faraday.proxy {}
    connection.use JWTSerializer
    connection.use RequestIdMiddleware
    if Rails.env.production? || Rails.env.staging?
      connection.use ZipkinTracer::FaradayHandler, 'Set service'
    end
  end
end
