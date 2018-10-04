# frozen_string_literal: true

# Helper query object for owned work plans
module WorkPlans
  # Returns an ActiveRecord relation of work plans owned by the given user
  class ForUserQuery
    class << self
      delegate :call, to: :new
    end

    def initialize(relation = WorkPlan.all)
      @relation = relation
    end

    def call(user)
      @relation.where(owner_email: user.email)
    end
  end
end
