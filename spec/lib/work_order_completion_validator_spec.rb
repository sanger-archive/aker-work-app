require 'rails_helper'
require 'work_order_completion_validator'

RSpec.describe 'WorkOrderCompletionValidator' do
  describe '#validate' do
    it 'validates using a json schema from assets folder' do
      expect(WorkOrderCompletionValidator.validate(FactoryGirl.build(:work_order_completion_message_json))).to eq(true)
    end
  end
end