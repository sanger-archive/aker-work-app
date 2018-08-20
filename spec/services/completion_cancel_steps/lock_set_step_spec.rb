require 'rails_helper'
require 'support/test_services_helper'
require 'completion_cancel_steps/lock_set_step'

RSpec.describe 'LockSetStep' do
  include TestServicesHelper

  let(:work_plan) { create :work_plan }

  let(:work_order) { create(:work_order, order_index: 1, work_plan: work_plan) }


  let(:job) { create :job, work_order: work_order, set_uuid: original_set.uuid }

  let(:original_set) {
    uuid = made_up_uuid
    s = instance_double('set', locked: false, owner_id: work_order.owner_email, id: uuid, uuid: uuid)
    allow(s).to receive(:materials).and_return(materials)
    allow(SetClient::Set).to receive(:find_with_materials).and_return([s])
    s
  }

  let(:materials) { [make_material] }
  let(:updated_materials) { [make_material] }

  let(:step) do
    material_step = double('material_step', materials: materials)
    updated_material_step = double('material_step', materials: updated_materials)
    LockSetStep.new(job.decorate, {}, material_step, updated_material_step)
  end

  setup do
    stub_matcon
    allow_set_service_lock_set
  end

  describe '#up' do
    context 'when there are no materials' do
      let(:updated_materials) { [] }
      let(:materials) { [] }
      it 'does nothing' do
        expect(SetClient::Set).not_to receive(:create)
        step.up
      end
    end
    context 'when there are changed materials' do
      it 'creates a locked set for the materials updated in the job and release materials' do
        created_set = double('set', id: 'someidentifier')
        allow(SetClient::Set).to receive(:create).and_return(created_set)
        expect(created_set).to receive(:set_materials)
        expect(created_set).to receive(:update_attributes).with(owner_id: work_plan.owner_email, locked: true)
        expect(step).to receive(:set_materials_availability).with(true)
        step.up
      end
    end
  end
  describe '#down' do
    it 'unsets the set from the job and claim back the materials' do
      job.update_attributes(set_uuid: SecureRandom.uuid)
      job.reload
      expect(step).to receive(:set_materials_availability).with(false)
      step.down
      job.reload
      expect(job.set_uuid).to eq(nil)
    end
  end
end
