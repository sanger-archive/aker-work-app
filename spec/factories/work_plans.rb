# frozen_string_literal: true

FactoryBot.define do
  factory :work_plan do
    owner_email 'owner@sanger.ac.uk'
    uuid { SecureRandom.uuid }
  end
end
