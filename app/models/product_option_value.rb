class ProductOptionValue < ApplicationRecord
  belongs_to :product_option
  has_many :item_option_selections
end
