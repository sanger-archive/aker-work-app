require 'rails_helper'

RSpec.describe 'EventMessage' do
  context '#initialize' do
    it 'is initalized with a param object' do
      w = double('work_order')
      message = EventMessage.new(work_order: w)
      expect(message.work_order).not_to be_nil
    end
  end
  context '#generate_json' do
    it 'generates a json' do
      #pending 'TODO'
    end
  end
end