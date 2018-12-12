# frozen_string_literal: true

FactoryBot.define do
  factory :job do
    work_order
    input_set_uuid { SecureRandom.uuid }

    trait :started do
      started { 2.weeks.ago }
    end

    trait :cancelled do
      cancelled { 1.week.ago }
      output_set_uuid { SecureRandom.uuid }
    end

    trait :completed do
      completed { 1.day.ago }
      output_set_uuid { SecureRandom.uuid }
    end

    trait :revised_output do
      revised_output_set_uuid { SecureRandom.uuid }
    end

    trait :forwarded do
      forwarded { 1.day.ago }
    end

    factory :started_job, traits: [:started]
    factory :cancelled_job, traits: [:started, :cancelled]
    factory :completed_job, traits: [:started, :completed]
    factory :revised_output_job, traits: [:started, :completed, :revised_output]
    factory :forwarded_job, traits: [:started, :completed, :forwarded]
    factory :revised_forwarded_job, traits: [:started, :completed, :revised_output, :forwarded]
  end
end
