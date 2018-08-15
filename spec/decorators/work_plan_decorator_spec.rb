# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkPlanDecorator do

  let(:work_plan) { create(:work_plan) }
  let(:decorated_work_plan) { work_plan.decorate }
  let(:set) { double("SetClient::Set", uuid: SecureRandom.uuid) }

  it_behaves_like "linkable_to_sets", [:original_set_uuid] do
    let(:model_name) { :work_plan }
  end

  it_behaves_like "linkable_to_projects", [:project_id] do
    let(:model_name) { :work_plan }
  end

  describe 'delegation' do

    it 'delegates to the WorkPlan' do
      expect(decorated_work_plan.created_at).to eql(work_plan.created_at)
      expect(decorated_work_plan.updated_at).to eql(work_plan.updated_at)
      expect(decorated_work_plan.comment).to eql(work_plan.comment)
      expect(decorated_work_plan.owner_email).to eql(work_plan.owner_email)
      expect(decorated_work_plan.data_release_strategy_id).to eql(work_plan.data_release_strategy_id)
    end

  end

  describe '#work_orders' do
    let(:work_plan) { build(:work_plan, work_orders: build_list(:work_order, 3))}

    it 'returns a collection of WorkOrders' do
      expect(decorated_work_plan.work_orders.length).to eql(3)
      expect(decorated_work_plan.work_orders).to all be_instance_of(WorkOrder)
    end

  end
end