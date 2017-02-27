class WorkOrder < ApplicationRecord
  has_one :item, inverse_of: :work_order, dependent: :destroy
  accepts_nested_attributes_for :item

  before_save :create_locked_set, if: -> { original_set_uuid_changed? }

  def self.ACTIVE
    'active'
  end

  scope :active, -> { where(status: WorkOrder.ACTIVE) }
  scope :pending, -> { where.not(status: WorkOrder.ACTIVE) }

  def active?
    status == WorkOrder.ACTIVE
  end

  def original_set
    return nil unless original_set_uuid
    return @original_set if @original_set&.uuid==original_set_uuid
    @original_set = AkerSet.find(original_set_uuid)
  end

  def original_set=(orig_set)
    self.original_set_uuid = orig_set&.uuid
    @original_set = orig_set
  end

  def set
    return nil unless set_uuid
    return @set if @set&.uuid==set_uuid
    @set = AkerSet.find(set_uuid)
  end

  def set=(set)
    self.set_uuid = set&.uuid
    @set = set
  end

  # Create a locked set from this work order's original set.
  def create_locked_set
    self.set = original_set.create_locked_clone("Work order #{id}")
  end

end
