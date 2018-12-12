FactoryBot.define do
  factory :aker_process, aliases: [:process], class: 'Aker::Process' do
    sequence(:name) { |i| "Process #{i}" }
    TAT { 1 }
    uuid { SecureRandom.uuid }

    factory :aker_process_with_work_orders do

      transient do
        work_order_count { 3 }
      end

      after(:create) do |process, evaluator|
        create_list(:work_order_with_jobs, evaluator.work_order_count, process: process)
      end

    end
  end
end
