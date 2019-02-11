# frozen_string_literal: true

FactoryBot.define do
  factory :work_plan do
    owner_email { 'owner@sanger.ac.uk' }
    uuid { SecureRandom.uuid }

    transient do
      status { :construction }
      work_order_count { 1 }
    end

    trait :with_original_set do
      original_set_uuid { SecureRandom.uuid }
    end

    trait :with_project do
      project_id { SecureRandom.uuid }
    end

    trait :with_product do
      after(:create) do |plan, evaluator|
        plan.product = create(:product_with_processes)
        plan.save!
      end
    end

    trait :with_drs do
      data_release_strategy
    end

    after(:create) do |plan, evaluator|
      if %i[active closed broken cancelled].include?(evaluator.status)
        plan.cancelled = 1.day.ago if evaluator.status == :cancelled
        plan.project_id = evaluator.project_id || build(:project).id
        unless evaluator.status == :cancelled
          work_order_factory = "#{evaluator.status}_work_order".to_sym
          create_list(work_order_factory, evaluator.work_order_count, work_plan: plan)
        end
      end
      plan.save!
    end

    factory :startable_work_plan, traits: [:with_original_set, :with_project, :with_product, :with_drs]

  end
end
