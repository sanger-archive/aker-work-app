require 'rails_helper'

RSpec.describe Aker::ProcessModulePairings, type: :model do
  describe "#validation" do
    it 'is not valid without either from_step or to_step' do
      aker_process = create(:aker_process)
      expect{ create(:aker_process_module_pairings, from_step_id: nil, to_step_id: nil, aker_process_id: aker_process.id)}
      .to raise_error(/A pairing cannot have nil in both from_step and to_step at the same time/)
    end
  end

end