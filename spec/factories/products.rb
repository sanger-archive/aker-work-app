FactoryBot.define do
  factory :product do
    catalogue
    name "MyProduct"
    availability :available
    uuid { SecureRandom.uuid }
  end
end
