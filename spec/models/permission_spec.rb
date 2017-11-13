require 'rails_helper'

RSpec.describe AkerPermissionGem::Permission, type: :model do
  let(:work_order) { create(:work_order) }

  describe '#permitted' do
    it 'should be sanitised' do
      expect(described_class.create(accessible: work_order, permitted: '   ALPHA@BETA  ', permission_type: :write).permitted).to eq('alpha@beta')
    end
  end
end