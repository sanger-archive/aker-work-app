require 'set_service_client'

class AkerSet
	include ActiveModel::Model

	validates :id, presence: true

	def self.get_sets
		SetServiceClient.get_sets
	end

end
