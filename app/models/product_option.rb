class ProductOption < ApplicationRecord
  belongs_to :product
  has_many :product_option_values, dependent: :destroy
  has_many :item_option_selections
end
