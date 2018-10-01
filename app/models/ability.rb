# This class overrights the aker-permission-gem Ability class
# as we want to check permissions against an OpenStruct user object
# rather than just the users' email or users' groups

# https://github.com/CanCanCommunity/cancancan/wiki/defining-abilities
class Ability
  include CanCan::Ability

  def initialize(user)
    can do |permission_type, subject_class, subject|
      if !user && !subject
        permission_type==:read
      elsif !subject
        [:create, :read].include?(permission_type)
      else
        permitted?(subject, user, permission_type)
      end
    end
  end

  def permitted?(accessible, user, permission_type)
    return (permission_type==:read) if user.nil?
    permission_type==:create || accessible&.user_permitted?(user, permission_type)
  end

end
