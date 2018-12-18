require "faraday"

# Client to access the Data release strategies, currently accessed from Sequencescape
module DataReleaseStrategyClient

  # Returns the data release strategy by uuid.
  def self.find_strategy_by_uuid(uuid)
    if uuid
      DataReleaseStrategy.find_by(id: uuid)
    end
  end

  # Gets the list of strategies available for the user. It also updates the current database with
  # the response, as this keeps the local copy for the name of data releases up to date
  def self.find_strategies_by_user(user)
    conn = get_connection

    username = user.gsub(/@.*/, '')

    begin
      studies = JSON.parse(conn.get('/api/v2/studies?filter[state]=active&filter[user]='+username).body)['data']
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error("Failed to fetch Data Release Strategies for user: #{username}")
      Rails.logger.error e.message
      Rails.logger.error e.backtrace.join("\n")
      # Re-raise the error so Rails shows an error page. Fail noisily.
      raise
    end

    studies.map do |study|
      strategy = DataReleaseStrategy.find_or_create_by(id: study['attributes']['uuid'])
      strategy.update_with_study_info(study)
      strategy
    end.uniq
  end

  # Connection to access the data release server
  def self.get_connection
    conn = Faraday.new(:url => Rails.application.config.sequencescape_url) do |faraday|
      faraday.request  :url_encoded
      faraday.response :logger
      faraday.adapter  Faraday.default_adapter
    end
    conn.headers = {'Accept' => 'application/vnd.api+json', 'Content-Type' => 'application/vnd.api+json'}
    conn
  end

end


