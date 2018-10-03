# frozen_string_literal: true

FactoryBot.define do
  factory :work_order do
    work_plan
    process
    order_index 1
    
    trait :active do
      status 'active'
    end

    trait :broken do
      status 'broken'
    end

    trait :closed do
      status 'concluded'
      completion_date 1.day.ago
    end

    factory :active_work_order, traits: [:active]
    factory :closed_work_order, traits: [:closed]
    factory :broken_work_order, traits: [:broken]

    factory :work_order_with_jobs, traits: [:queued] do

      transient do
        job_count 3
      end

      after(:create) do |work_order, evaluator|
        create_list(:job, evaluator.job_count, work_order: work_order)
      end
    end
  end
end
