class Item < ApplicationRecord
  has_many :item_option_selections, inverse_of: :item, dependent: :destroy
  belongs_to :work_order, inverse_of: :item
  belongs_to :product, inverse_of: :items

  accepts_nested_attributes_for :item_option_selections

  before_save :set_item_option_selections, if: -> { product_id_changed? }

  before_create :set_item_option_selections

  def proposal_id
  end

private

  def set_item_option_selections
    item_option_selections.clear

    product.product_options.each do |po|
      item_option_selections << po.item_option_selections.build(item: self)
    end
  end
end
