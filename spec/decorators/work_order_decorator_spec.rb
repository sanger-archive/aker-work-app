# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkOrderDecorator do

  let(:work_order) { create(:work_order) }
  let(:decorated_work_order) { work_order.decorate }
  let(:set) { double("SetClient::Set", uuid: SecureRandom.uuid) }
  let(:locked_set) { double("SetClient::Set", uuid: SecureRandom.uuid, locked: true) }

  it_behaves_like "linkable_to_sets", [:set_uuid] do
    let(:model_name) { :work_order }
  end

  describe 'delegation' do

    it 'delegates to the WorkOrder' do
      expect(decorated_work_order.status).to eql(work_order.status)
      expect(decorated_work_order.created_at).to eql(work_order.created_at)
      expect(decorated_work_order.updated_at).to eql(work_order.updated_at)
      expect(decorated_work_order.total_cost).to eql(work_order.total_cost)
      expect(decorated_work_order.order_index).to eql(work_order.order_index)
      expect(decorated_work_order.dispatch_date).to eql(work_order.dispatch_date)
    end

  end

  describe '#jobs' do
    let(:work_order) { build(:work_order, jobs: build_list(:job, 3))}

    it 'returns a collection of Jobs' do
      expect(decorated_work_order.jobs.length).to eql(3)
      expect(decorated_work_order.jobs).to all be_instance_of(Job)
    end
  end

  describe '#work_plan' do
    it 'returns a WorkPlan' do
      expect(decorated_work_order.work_plan).to be_instance_of WorkPlan
    end
  end

end