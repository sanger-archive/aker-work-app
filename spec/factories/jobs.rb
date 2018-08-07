# frozen_string_literal: true

FactoryBot.define do
  factory :job do
    work_order
    uuid { SecureRandom.uuid }

    trait :started do
      started 2.weeks.ago
    end

    trait :cancelled do
      cancelled 1.week.ago
    end

    trait :completed do
      completed 1.day.ago
    end

    factory :cancelled_job, traits: [:started, :cancelled]
    factory :completed_job, traits: [:started, :completed]
  end
end
