FactoryBot.define do
  factory :aker_product_process, aliases: [:product_process], class: 'Aker::ProductProcess' do
    product
    aker_process
    sequence(:stage) { |n| n }
  end
end
