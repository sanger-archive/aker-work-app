# frozen_string_literal: true

FactoryBot.define do
  factory :project, class: StudyClient::Node do

    sequence(:id) { |n| n }
    type { "nodes" }
    sequence(:name) { |n| "Project #{n}" }
    add_attribute("cost-code") { 'S0001' }
    description { "Here is my project... for science" }
    created_at { rand(365).days.ago }
    add_attribute("parent-id") { id + 99 }

    meta { { active: true } }

    trait :inactive do
      meta { { active: false } }
    end

  end
end
