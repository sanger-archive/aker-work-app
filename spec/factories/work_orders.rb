FactoryBot.define do
  factory :work_order do
    work_plan
    process
    order_index 1
  end
end
