require 'faraday'

module LimsClient

  def self.post(url, params)
    r = Faraday.new(url: url).post('', params.to_json)
    unless r.status>=200 && r.status<400
    	raise "LimsClient post failed"
    end
  end

  def self.get_connection(url)
    Faraday.new(:url => url) do |faraday|
      faraday.use ZipkinTracer::FaradayHandler, 'work order service'
    end
  end
end
