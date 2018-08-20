Rails.application.config.after_initialize do

  StudyClient::Node.include AkerPermissionClientConfig

  StudyClient::Base.site = Rails.application.config.study_url

  StudyClient::Base.connection do |connection|
    ENV['HTTP_PROXY'] = nil
    ENV['http_proxy'] = nil
    ENV['https_proxy'] = nil
    connection.faraday.proxy {}
    connection.use JWTSerializer
    connection.use RequestIdMiddleware
    if Rails.env.production? || Rails.env.staging?
      connection.use ZipkinTracer::FaradayHandler, 'Study service'
    end
  end
end
