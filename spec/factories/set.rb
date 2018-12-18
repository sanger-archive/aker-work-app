# frozen_string_literal: true

FactoryBot.define do
  factory :set, class: SetClient::Set do

    type { "sets" }
    id { SecureRandom.uuid }
    meta { { "size" => rand(1000) } }

    sequence(:name) { |n| "Set #{n}" }
    owner_id { "ab12@sanger.ac.uk" }

    created_at { rand(365).days.ago }

    locked { false }

    trait :locked do
      locked { true }
    end

  end
end
