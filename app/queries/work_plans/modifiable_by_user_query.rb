# frozen_string_literal: true

require 'study'

# Helper query object for modifiable work plans
module WorkPlans
  # Returns an ActiveRecord relation of work plans owned by the given user OR
  # plans where the given user has spend permissions on the plans' project.
  class ModifiableByUserQuery < ForUserQuery
    attr_reader :user
    class << self
      delegate :call, to: :new
    end

    def initialize(relation = WorkPlan.all)
      @relation = relation
    end

    def call(user)
      @user = user
      user_plans.or(spendable_plans)
    end

    private

    def user_plans
      WorkPlans::ForUserQuery.call(user)
    end

    def spendable_plans
      spendable_projects_ids = Study.spendable_projects(user).map(&:id).map(&:to_i)
      @relation.where(project_id: spendable_projects_ids)
    end
  end
end
