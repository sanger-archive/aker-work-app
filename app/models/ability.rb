# frozen_string_literal: true

# This class overwrites the aker-permission-gem Ability class
# as we want to check permissions against an OpenStruct user object
# rather than just the users' email or users' groups

# https://github.com/CanCanCommunity/cancancan/wiki/defining-abilities
class Ability
  include CanCan::Ability

  def initialize(user)
    can do |permission_type, _subject_class, subject|
      if !user
        permission_type == :read
      elsif !subject
        %i[create read].include?(permission_type)
      else
        permitted?(subject, user, permission_type)
      end
    end
  end

  def permitted?(accessible, user, permission_type)
    permission_type == :create || accessible&.user_permitted?(user, permission_type)
  end
end
