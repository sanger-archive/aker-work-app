# frozen_string_literal: true

FactoryBot.define do
  factory :work_plan do
    owner_email 'owner@sanger.ac.uk'
    uuid { SecureRandom.uuid }

    transient do
      status { :construction }
      work_order_count { 1 }
    end

    trait :with_project do
      project_id SecureRandom.uuid
    end

    after(:create) do |plan, evaluator|
      if %i[active closed broken cancelled].include?(evaluator.status)
        plan.cancelled = 1.day.ago if evaluator.status == :cancelled
        plan.project_id = SecureRandom.uuid
        unless evaluator.status == :cancelled
          work_order_factory = "#{evaluator.status}_work_order".to_sym
          create_list(work_order_factory, evaluator.work_order_count, work_plan: plan)
        end
      end
      plan.save!
    end
  end
end
