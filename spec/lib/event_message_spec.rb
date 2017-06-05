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
      wo = build(:work_order, {user: user, status: WorkOrder.ACTIVE})

      message = EventMessage.new(work_order: wo)
      json = JSON.parse(message.generate_json)
      expect(json["event_type"]).to eq 'aker.events.work_order.active'
      expect(json["user_identifier"]).to eq 'user@here.com'
    end
  end

end