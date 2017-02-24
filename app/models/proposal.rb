require 'study_management_client'

class Proposal
	include ActiveModel::Model

	attr_accessor :id, :name, :cost_code

	def self.new_from_json(data)
		new(id: data[:id],
            name: data[:name],
            cost_code: data[:cost_code])
	end

	def self.get_proposals
		StudyManagementClient.get_proposals.map { |data| new_from_json(data) }
	end

	def self.find(id)
		# check string conversions ie id.inspect ??
        new_from_json(StudyManagementClient::get_proposal(id.inspect)[0])
    end

end
