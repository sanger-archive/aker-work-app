class Product < ApplicationRecord
  belongs_to :shop, optional: true
  has_many :items, inverse_of: :product
  has_many :product_options, dependent: :destroy
end
