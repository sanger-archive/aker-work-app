class WorkOrder < ApplicationRecord
  has_one :item, inverse_of: :work_order, dependent: :destroy

  accepts_nested_attributes_for :item

  attr_accessor :proposal_id, :name

  scope :active, -> { where(status: 'active') }
  scope :pending, -> { where.not(status: 'active') }

  def active?
    status == 'active'
  end

end
