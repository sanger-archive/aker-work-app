class Product < ApplicationRecord
  belongs_to :catalogue

  after_initialize :create_uuid

  enum availability: { suspended: 0, available: 1 }

  def create_uuid
    self.product_uuid ||= SecureRandom.uuid
  end
end
