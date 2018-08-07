# frozen_string_literal: true

FactoryBot.define do
  factory :work_order do
    work_plan
    process
    order_index 1

    trait :queued do
      status 'queued'
    end

    factory :dispatchable_work_order, traits: [:queued]

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
