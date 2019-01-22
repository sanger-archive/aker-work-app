require 'rails_helper'

RSpec.describe DispatchableWorkOrderPolicy do

  let(:project) { build(:project) }
  let(:subproject) { build(:project, "parent-id": project.id) }
  let(:work_plan) { create(:work_plan, project_id: subproject.id, status: :active) }
  let(:process_modules) { [] }
  let(:available_material) { double(MatconClient::Material, available: true) }
  let(:unavailable_material) { double(MatconClient::Material, available: false) }
  let(:materials) { [available_material, available_material, available_material] }
  let(:work_order) { create(:work_order_with_jobs, work_plan: work_plan, process_modules: process_modules) }
  let(:dwop) { DispatchableWorkOrderPolicy.new }

  before :each do
    allow(UbwClient).to receive(:missing_unit_prices).and_return([])
    allow(StudyClient::Node).to receive(:find).with(subproject.id).and_return([subproject])
    allow(StudyClient::Node).to receive(:find).with(project.id).and_return([project])
    allow(dwop).to receive(:materials).and_return(materials)
  end

  describe '#initialise' do

    it 'requires a Work Order' do
      expect { dwop }.not_to raise_error
    end

    it 'adds an errors object' do
      expect(dwop.errors).to be_kind_of ActiveModel::Errors
    end

  end

  describe '#dispatchable?' do

    context 'when Work Order status is not "queued"' do

      let(:work_order) { create(:work_order_with_jobs, status: "active", work_plan: work_plan) }

      it 'is false' do
        expect(dwop.dispatchable?(work_order)).to be false
        expect(dwop.errors.full_messages).to eql(['Work order must have status \'queued\''])
      end

    end

    context 'when Work Order\'s Work Plan status is not "active"' do

      let(:work_plan) { create(:work_plan, status: :broken, project_id: subproject.id) }

      it 'is false' do
        expect(dwop.dispatchable?(work_order)).to be false
        expect(dwop.errors.full_messages).to eql(['Work plan must have status \'active\''])
      end

    end

    context 'when Work Order has invalid modules' do
      let(:process_modules) { [build(:process_module, name: 'Invalid')] }

      before do
        allow(UbwClient).to receive(:missing_unit_prices) { |module_names, cost_code| module_names }
      end

      it 'is false' do
        expect(dwop.dispatchable?(work_order)).to be false
        expect(dwop.errors.full_messages).to eql(['Process modules could not be validated: ["Invalid"]'])
      end

    end

    context 'when Work Plan\'s Project\'s Cost Code is nil' do
      let(:subproject) { build(:project, "parent-id": nil) }

      it 'is false' do
        expect(dwop.dispatchable?(work_order)).to be false
        expect(dwop.errors.full_messages).to eql(['Cost code can not be found for this Work Plan'])
      end

    end

    context 'when any Materials are not available' do

      let(:materials) { [available_material, unavailable_material, available_material] }

      it 'is false' do
        expect(dwop.dispatchable?(work_order)).to be false
        expect(dwop.errors.full_messages).to eql(['Materials are not all available'])
      end
    end

    context 'when WorkOrder does not have any Jobs' do
      let(:work_order) { create(:queued_work_order, work_plan: work_plan) }

      it 'is false' do
        expect(dwop.dispatchable?(work_order)).to be false
        expect(dwop.errors.full_messages).to eql(['Work order does not have any Jobs'])
      end
    end

  end

end