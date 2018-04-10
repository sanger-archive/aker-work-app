require 'rails_helper'
require 'support/test_services_helper'
require 'completion_cancel_steps/lock_set_step'

RSpec.describe 'LockSetStep' do
  include TestServicesHelper

  let(:work_order) do
    wo = make_work_order
    allow(wo).to receive(:next_order).and_return(next_order)
    wo
  end

  let(:job) {
    job = create :job
    allow(job).to receive(:work_order).and_return(work_order)
    job
  }

  let(:finished_set) do
    uuid = made_up_uuid
    s = instance_double('set', locked: false, owner_id: work_order.owner_email, id: uuid, uuid: uuid)
    allow(SetClient::Set).to receive(:create).and_return(s)
    s
  end

  let(:materials) { [make_material] }

  let(:step) do
    material_step = double('material_step', materials: materials)
    LockSetStep.new(job, {}, material_step)
  end

  setup do
    stub_matcon
  end

  describe '#up' do
    context 'when the work order is not concluded' do
      before do
        allow(work_order).to receive(:status).and_return('active')
      end

      let(:next_order) { make_work_order }
      it 'does nothing' do
        expect(work_order).not_to receive(:update_attributes!)
        step.up
      end
    end
    context 'when the work order is concluded' do
      context 'when there is a next order' do

        let(:next_order) { make_work_order }
        before do
          allow(work_order).to receive(:status).and_return('concluded')
        end

        it 'updates the set and the next order' do
          expect(work_order).to receive(:update_attributes!).with(finished_set_uuid: finished_set.id)
          expect(next_order).to receive(:update_attributes!).with(original_set_uuid: finished_set.id)
          expect(finished_set).to receive(:set_materials).with(materials.map(&:id))
          expect(finished_set).to receive(:update_attributes).with(owner_id: work_order.owner_email, locked: true)
          step.up
        end
      end
      context 'when this is the last order' do
        before do
          allow(work_order).to receive(:status).and_return('concluded')
        end

        let(:next_order) { nil }
        it 'updates the set' do
          expect(work_order).to receive(:update_attributes!).with(finished_set_uuid: finished_set.id)
          expect(finished_set).to receive(:set_materials).with(materials.map(&:id))
          expect(finished_set).to receive(:update_attributes).with(owner_id: work_order.owner_email, locked: true)
          step.up
        end
      end
    end
  end

  describe '#down' do
    context 'when there is a next order' do
      before do
        allow(work_order).to receive(:status).and_return('concluded')
      end

      let(:next_order) { make_work_order }
      it 'sets the finished set to nil and sets the next order original set to nil' do
        allow(work_order).to receive(:finished_set_uuid).and_return(finished_set.uuid)
        allow(next_order).to receive(:original_set_uuid).and_return(finished_set.uuid)
        expect(work_order).to receive(:update_attributes!).with(finished_set_uuid: nil)
        expect(next_order).to receive(:update_attributes!).with(original_set_uuid: nil)
        step.down
      end
    end

    context 'when there is not a next order' do
      before do
        allow(work_order).to receive(:status).and_return('concluded')
      end

      let(:next_order) { nil }
      it 'sets the finished set to nil' do
        allow(work_order).to receive(:finished_set_uuid).and_return(finished_set.uuid)
        expect(work_order).to receive(:update_attributes!).with(finished_set_uuid: nil)
        step.down
      end
    end
  end
end
