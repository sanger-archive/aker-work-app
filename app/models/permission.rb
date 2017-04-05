class Permission < ApplicationRecord
  belongs_to :accessible, polymorphic: true
  belongs_to :user
end
