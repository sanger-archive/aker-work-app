class ItemOptionSelection < ApplicationRecord
  belongs_to :item, inverse_of: :item_option_selections
  belongs_to :product_option
  belongs_to :product_option_value
end
