require 'rails_helper'
require 'work_order_completion_validator'
require 'support/test_services_helper'

RSpec.describe 'WorkOrderCompletionValidator' do
  include TestServicesHelper
  describe '#validate' do
    setup do
      webmock_matcon_schema
    end
    it 'validates using a json schema from assets folder' do
      expect(WorkOrderCompletionValidator.validate(FactoryGirl.build(:work_order_completion_message_json))).to eq([])
    end
  end
end