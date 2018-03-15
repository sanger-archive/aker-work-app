FactoryBot.define do
  factory :aker_process, aliases: [:process], class: 'Aker::Process' do
    name 'processname'
    TAT 1
    uuid { SecureRandom.uuid }
  end
end
