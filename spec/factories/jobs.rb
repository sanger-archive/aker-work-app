# frozen_string_literal: true

FactoryBot.define do
  factory :job do
    work_order
    uuid { SecureRandom.uuid }
  end
end
