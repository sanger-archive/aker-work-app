require 'rails_helper'
require 'support/test_services_helper'
require 'completion_cancel_steps/create_master_set_step'

RSpec.describe 'CreateMasterSetStep' do
  include TestServicesHelper

  let(:work_plan) { create :work_plan }

  let(:work_order) { create(:work_order, order_index: 1, work_plan: work_plan) }


  let(:job) { create :job, work_order: work_order, set_uuid: original_set.uuid }

  let(:finished_set) do
    uuid = made_up_uuid
    s = instance_double('set', locked: false, owner_id: work_order.owner_email, id: uuid, uuid: uuid)
    allow(s).to receive(:destroy).and_return(true)
    allow(SetClient::Set).to receive(:create).and_return(s)
    s
  end

  let(:original_set) {
    uuid = made_up_uuid
    s = instance_double('set', locked: false, owner_id: work_order.owner_email, id: uuid, uuid: uuid)
    allow(s).to receive(:materials).and_return(materials)
    allow(SetClient::Set).to receive(:find_with_materials).and_return([s])
    s
  }

  let(:materials) { [make_material] }

  let(:step) do
    material_step = double('material_step', materials: materials)
    updated_material_step = double('material_step', materials: materials)
    CreateMasterSetStep.new(job)
  end

  setup do
    stub_matcon
    allow_set_service_lock_set
  end

  describe '#up' do
    context 'when the work order is not concluded' do
      before do
        work_order.update_attributes(status: WorkOrder.ACTIVE)
      end

      it 'does nothing' do
        expect(work_order).not_to receive(:update_attributes!)
        step.up
      end
    end

    context 'when the work order is concluded' do
      setup do
        work_order.update_attributes(status: WorkOrder.CONCLUDED)
      end

      context 'when the work_order has a Master Set' do
        before do
          work_order.update_attributes(finished_set_uuid: made_up_uuid)
        end

        it 'does nothing' do
          expect(work_order).not_to receive(:update_attributes!)
          step.up
        end
      end

      context 'when there is a next order' do
        before do
          @next_order = create(:work_order, order_index: 2, work_plan: work_plan)
        end

        it 'updates the set and the next order' do
          expect(work_order).to receive(:update_attributes!).with(finished_set_uuid: finished_set.id)
          expect(finished_set).to receive(:set_materials).with(materials.map(&:id))
          expect(finished_set).to receive(:update_attributes).with(owner_id: work_order.owner_email, locked: true)
          expect(@next_order.original_set_uuid).to eq(nil)
          step.up
          @next_order.reload
          expect(@next_order.original_set_uuid).to eq(finished_set.id)
        end
      end
      context 'when this is the last order' do

        it 'updates the set' do
          expect(finished_set).to receive(:set_materials).with(materials.map(&:id))
          expect(finished_set).to receive(:update_attributes).with(owner_id: work_order.owner_email, locked: true)
          step.up
          work_order.reload
          expect(work_order.finished_set_uuid).to eq(finished_set.id)
        end
      end
    end
  end

  describe '#down' do
    context 'when there is a next order' do
      before do
        @next_order = create(:work_order, order_index: 2, work_plan: work_plan)
      end

      it 'sets the finished set to nil and sets the next order original set to nil' do
        step.down
        expect(work_order.finished_set_uuid).to eq(nil)
        expect(@next_order.original_set_uuid).to eq(nil)
      end
    end

    context 'when there is not a next order' do
      it 'sets the finished set to nil' do
        step.down
        expect(work_order.finished_set_uuid).to eq(nil)
      end
    end

    context 'when Master Set is created and locked' do
      before do
        allow(finished_set).to receive(:locked).and_return(true)
        step.master_set = finished_set
      end

      it 'does\'t destroy the Master Set' do
        expect(finished_set).to_not receive(:destroy)
        step.down
      end

    end

    context 'when Master Set is created but not locked' do
      before do
        step.master_set = finished_set
      end

      it 'destroys the Master Set' do
        expect(finished_set).to receive(:destroy)
        step.down
      end
    end
  end
end
