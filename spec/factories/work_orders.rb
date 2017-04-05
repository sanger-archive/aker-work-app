FactoryGirl.define do
  factory :work_order do
    user
    original_set_uuid SecureRandom.uuid
  end
end
