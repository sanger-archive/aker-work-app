FactoryGirl.define do
  factory :work_order do
    user_id { create(:user).id }
    original_set_uuid SecureRandom.uuid
  end
end
