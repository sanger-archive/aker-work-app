FactoryBot.define do
  factory :data_release_strategy do
    id SecureRandom.uuid
    name { generate(:data_release_strategy_name) }
    study_code { 'acode' }
  end

  sequence :data_release_strategy_name do |n|
    "Strategy #{n}"
  end
end