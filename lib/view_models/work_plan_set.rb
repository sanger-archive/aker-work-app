# frozen_string_literal: true

# A ViewModel for the plan wizard set view
module ViewModels
  class WorkPlanSet

    attr_reader :work_plan
    delegate :original_set, :original_set_uuid, :original_set_uuid?, to: :work_plan

    def initialize(args)
      @work_plan = args.fetch(:work_plan).decorate
      @user      = args.fetch(:user)
    end

    def form_enabled?
      work_plan.in_construction?
    end

    def sets
      if work_plan.in_construction?
        get_non_empty_user_sets
      else
        [original_set]
      end
    end

    def set_names
      sets.map { |set| set.name.downcase }
    end

  private

    attr_reader :user

    def get_non_empty_user_sets
      SetClient::Set.where(owner_id: user.email, empty: false).order(created_at: :desc).all
    end

  end
end