class WorkOrder < ApplicationRecord
  has_one :item, inverse_of: :work_order, dependent: :destroy
  accepts_nested_attributes_for :item

  scope :active, -> { where(status: 'active') }
  scope :pending, -> { where.not(status: 'active') }

  def active?
    status == 'active'
  end

  def original_set
    return nil unless original_set_uuid
    return @original_set if @orginal_set&.uuid==original_set_uuid
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

end
