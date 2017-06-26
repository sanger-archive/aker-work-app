require 'rails_helper'
require 'support/test_services_helper'

RSpec.describe 'EventMessage' do
  include TestServicesHelper

  context '#initialize' do
    it 'is initalized with a param object' do
      w = double('work_order')
      allow(w).to receive(:status)
      message = EventMessage.new(work_order: w)
      expect(message.work_order).not_to be_nil
    end
  end

  context '#generate_json' do
    it 'generates a json' do
      user = build(:user, email: 'user@here.com')
      wo = build(:work_order, {user: user, status: WorkOrder.ACTIVE })
      set = double(:set, uuid: 'set_uuid', id: 'set_uuid', meta: { 'size' => '4' })
      proposal = double(:proposal, name: 'test proposal', node_uuid: '12345a')
      product = build(:product, name: 'test product', product_uuid: '23456b')

      allow(SecureRandom).to receive(:uuid).and_return 'a_uuid'
      allow(wo).to receive(:comment).and_return "A COMMENTTT"
      allow(wo).to receive(:total_cost).and_return "50"
      allow(wo).to receive(:desired_date).and_return "10-10-2001"

      allow(wo).to receive(:set).and_return set
      allow(wo).to receive(:proposal).and_return proposal
      allow(wo).to receive(:product).and_return product

      message = EventMessage.new(work_order: wo)

      allow(EventMessage).to receive(:trace_id).and_return 'a_trace_id'

      Timecop.freeze do
        json = JSON.parse(message.generate_json)

        expect(json["event_type"]).to eq 'aker.events.work_order.active'
        expect(json["lims_id"]).to eq 'aker'
        expect(json["uuid"]).to eq 'a_uuid'
        expect(json["timestamp"]).to eq Time.now.utc.iso8601
        expect(json["user_identifier"]).to eq user.email
        expect(json["metadata"]["comment"]).to eq wo.comment
        expect(json["metadata"]["quoted_price"]).to eq wo.total_cost
        expect(json["metadata"]["desired_completion_date"]).to eq wo.desired_date
        expect(json["metadata"]["zipkin_trace_id"]).to eq 'a_trace_id'
        expect(json["metadata"]["num_materials"]).to eq '4'
      end
    end
  end

end