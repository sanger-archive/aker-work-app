# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'

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

  describe '#parent_cost_code' do
    let(:project) { OpenStruct.new(id: 7, cost_code: 'S8421') }
    let(:subproject) { OpenStruct.new(id: 8, parent_id: project.id) }
    let(:work_plan) { create(:work_plan, project_id: subproject.id) }

    before do
      [project, subproject].each do |node|
        allow(StudyClient::Node).to receive(:find).with(node.id).and_return([node])
      end
      allow(StudyClient::Node).to receive(:find).with(nil).and_return([])
    end

    context 'when the work plan is linked to a subproject whose parent has a cost code' do
      it 'should return the cost code from the parent project' do
        expect(decorated_work_plan.parent_cost_code).to eq('S8421')
      end
    end

    context 'when the work plan is linked to a subproject whose parent has no cost code' do
      let(:project) { OpenStruct.new(id: 7, cost_code: nil) }

      it 'should return nil' do
        expect(decorated_work_plan.parent_cost_code).to be_nil
      end
    end

    context 'when the work plan is linked to a node without a parent' do
      let(:subproject) { OpenStruct.new(id: 8, parent_id: nil) }

      it 'should return nil' do
        expect(decorated_work_plan.parent_cost_code).to be_nil
      end
    end

    context 'when the work plan is not linked to any project' do
      let(:work_plan) { create(:work_plan, project_id: nil) }

      it 'should return nil' do
        expect(decorated_work_plan.parent_cost_code).to be_nil
      end
    end
  end
end
