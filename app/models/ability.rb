# https://github.com/CanCanCommunity/cancancan/wiki/Defining-Abilities
class Ability
  include CanCan::Ability

  def initialize(user)
    can :create, WorkOrder

    can :read, WorkOrder do |work_order|
      permitted?(work_order, user, :r)
    end

    can :write, WorkOrder do |work_order|
      permitted?(work_order, user, :w)
    end
  end

  def permitted?(work_order, user, access)
    work_order.permitted?(user.email, access) || work_order.permitted?(user.fetch_groups, access)
  end
end
