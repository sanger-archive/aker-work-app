require 'rails_helper'

RSpec.describe Aker::Process, type: :model do
  describe "#validation" do
    it 'is not valid without a name' do
      expect(build(:aker_process, name: nil, TAT: 1)).to_not be_valid
    end

    it 'is not valid without a unique name' do
      aker_process = create(:aker_process, name: 'processname', TAT: 1)
      expect(build(:aker_process, name: aker_process.name)).to_not be_valid
    end

    it 'is not valid without a TAT' do
      expect(build(:aker_process, name: 'processname', TAT: nil)).to_not be_valid
    end
  end
end