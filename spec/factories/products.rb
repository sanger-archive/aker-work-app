FactoryBot.define do
  factory :product do
    name "MyProduct"
    availability :available
    uuid { SecureRandom.uuid }
  end
end
