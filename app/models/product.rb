class Product < ApplicationRecord
  validates :catalogue_id, presence: true

  belongs_to :catalogue
  has_many :product_processes, -> { order(:stage) }, foreign_key: :product_id, dependent: :destroy, class_name: "Aker::ProductProcess"
  has_many :processes, -> { order('aker_product_processes.stage') }, through: :product_processes, source: :aker_process

  def self.available
    Product.where(availability: true)
  end

  def self.suspended
    Product.where(availability: false)
  end

  def available?
    self.availability
  end

  def suspended?
    !self.availability
  end

end
