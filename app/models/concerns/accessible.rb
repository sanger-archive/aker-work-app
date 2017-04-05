require 'active_support/concern'

module Accessible
  extend ActiveSupport::Concern

  included do
    has_many :permissions, as: :accessible
    after_create :set_permission

    def set_permission
      self.permissions.create([{ permitted: user.email, r: true, w: true }, { permitted: 'world', r: true }])
    end

    # Takes a user_or_group as a string e.g. "blackbeard@sanger.ac.uk" and an access parameter e.g. :r
    def permitted?(user_or_group, access)
      self.permissions.exists?(permitted: user_or_group, "#{access.to_s}": true)
    end
  end

end