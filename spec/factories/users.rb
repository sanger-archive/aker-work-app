FactoryGirl.define do
  factory :user do
    sequence(:email) { |n| "user_#{n}@sanger.ac.uk" }
  end
end
