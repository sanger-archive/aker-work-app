FactoryBot.define do
  factory :aker_process_module, aliases: [:process_module], class: 'Aker::ProcessModule' do
    aker_process
    name { generate(:aker_process_module_name) }
  end

  sequence :aker_process_module_name do |n|
    "Process #{n}"
  end
end
