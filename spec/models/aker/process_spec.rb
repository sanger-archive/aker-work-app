require 'rails_helper'

RSpec.describe Aker::Process, type: :model do
  describe "#validation" do
    it 'is not valid without a name' do
      expect(build(:aker_process, name: nil)).to_not be_valid
    end

    it 'is not valid without a uuid' do
      expect(build(:aker_process, uuid: nil)).to_not be_valid
    end

    it 'is not valid without a TAT' do
      expect(build(:aker_process, TAT: nil)).to_not be_valid
    end

    it 'is valid with required fields' do
      expect(build(:aker_process)).to be_valid
    end
  end
end