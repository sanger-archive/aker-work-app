class WorkOrder < ApplicationRecord
  has_one :item, inverse_of: :work_order, dependent: :destroy
  accepts_nested_attributes_for :item

  scope :active, -> { where(status: 'active') }
  scope :pending, -> { where.not(status: 'active') }

  def active?
    status == 'active'
  end

  def proposal
  	return nil unless proposal_id
    return @proposal if @proposal&.id==proposal_id
	@proposal = Proposal.find(proposal_id)
  end

end
