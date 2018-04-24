require 'rails_helper'

RSpec.describe Aker::ProcessModule, type: :model do
  describe "#validation" do
    it 'is not valid without a name' do
      expect(build(:aker_process_module, name: nil )).to_not be_valid
    end
  end

  describe "#to_custom_hash" do
    it "returns the name and id of a module" do
      aker_process = create(:aker_process)
      mod = Aker::ProcessModule.create!(name: 'mod1', aker_process_id: aker_process.id)
      expect(mod.to_custom_hash).to eq({name: mod.name, id: mod.id, min_value: nil, max_value: nil})
    end
  end

end