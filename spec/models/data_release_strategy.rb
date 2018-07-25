require 'rails_helper'

RSpec.describe DataReleaseStrategy, type: :model do

  describe "#label_to_display" do
    it "returns whats expected" do
      data_release_strategy = build(:data_release_strategy)
      expect(data_release_strategy.label_to_display).to eq 'acode Strategy 1'
    end
  end

  describe '#update_with_study_info' do
    context 'when the data release strategy has a new name' do
      let(:drs) { create(:data_release_strategy) }
      let(:study) { { id: drs.study_code, attributes: { name: 'anewname' }}.with_indifferent_access }
      it 'updates the name' do
        drs.update_with_study_info(study)
        drs.reload
        expect(drs.study_code).to eq drs.study_code
        expect(drs.name).to eq study['attributes']['name']
      end
    end
    context 'when the data release strategy has a new study code' do
      let(:drs) { create(:data_release_strategy) }
      let(:study) { { id: 'anewcode', attributes: { name: drs.name }}.with_indifferent_access }
      it 'updates the study code' do
        drs.update_with_study_info(study)
        drs.reload
        expect(drs.study_code).to eq study['id']
        expect(drs.name).to eq drs.name
      end
    end
  end
end
