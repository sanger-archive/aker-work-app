require 'study_management_client'

class Proposal
	include ActiveModel::Model

	validates :id, :cost_code, :name, presence: true

	def self.get_proposals
		StudyManagementClient.get_nodes_with_cost_code
	end

end
