require 'faraday'

module LimsClient

  def self.post(url, params)
    r = Faraday.new(url: url, headers: { 'Content-Type': 'application/json' }).post('', params.to_json)
    unless r.status>=200 && r.status<400
    	raise "LimsClient post failed. Response status: #{r.status}. #{r.body}"
    end
  end

end
