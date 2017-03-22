class Product < ApplicationRecord
  belongs_to :catalogue

  enum availability: { suspended: 0, available: 1 }
end
