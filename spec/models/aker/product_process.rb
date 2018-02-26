require 'rails_helper'

RSpec.describe Aker::Process, type: :model do
  describe "#validation" do
    it 'is not valid without a stage' do
      expect(build(:aker_product_process, stage: nil, aker_process_id: 1, product_id: 1 )).to_not be_valid
    end
  end
end