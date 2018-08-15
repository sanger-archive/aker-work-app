# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkOrderDecorator do

  let(:work_order) { create(:work_order) }
  let(:decorated_work_order) { work_order.decorate }
  let(:set) { double("SetClient::Set", uuid: SecureRandom.uuid) }
  let(:locked_set) { double("SetClient::Set", uuid: SecureRandom.uuid, locked: true) }

  it_behaves_like "linkable_to_sets", [:original_set_uuid, :set_uuid, :finished_set_uuid] do
    let(:model_name) { :work_order }
  end

  describe 'delegation' do

    it 'delegates to the WorkOrder' do
      expect(decorated_work_order.status).to eql(work_order.status)
      expect(decorated_work_order.created_at).to eql(work_order.created_at)
      expect(decorated_work_order.updated_at).to eql(work_order.updated_at)
      expect(decorated_work_order.total_cost).to eql(work_order.total_cost)
      expect(decorated_work_order.order_index).to eql(work_order.order_index)
      expect(decorated_work_order.dispatch_date).to eql(work_order.dispatch_date)
    end

  end

  describe '#finalise_set' do

    let(:set) { double("SetClient::Set", uuid: SecureRandom.uuid, locked: false, name: 'Work Order Set') }

    context 'when the order already has a locked input set' do
      before :each do
        decorated_work_order.set = locked_set
      end

      it 'should return false' do
        expect(decorated_work_order.finalise_set).to be false
      end
    end

    context 'when the order doesn\'t have a set or original set' do
      it 'raises an error' do
        expect { decorated_work_order.finalise_set }.to raise_exception "No set selected for Work Order"
      end
    end

    context 'when the order has an unlocked input set' do
      before :each do
        decorated_work_order.set = set
        expect(decorated_work_order.set).to receive(:update_attributes).with(locked: true).and_return(true)
      end

      it 'returns true' do
        expect(decorated_work_order.finalise_set).to be true
      end
    end

    context 'when the input set fails to be locked' do
      before :each do
        decorated_work_order.set = set
        expect(decorated_work_order.set).to receive(:update_attributes).with(locked: true).and_return(false)
      end

      it 'raises an exception' do
        expect { decorated_work_order.finalise_set }.to raise_exception "Failed to lock set #{set.name}"
      end
    end

    context 'when the order has a locked original set' do
      before :each do
        decorated_work_order.original_set = locked_set
      end

      it 'sets the input set to the original set' do
        expect(decorated_work_order.finalise_set).to be false
        expect(decorated_work_order.set_uuid).to eq(locked_set.uuid)
      end
    end

    context 'when the order has an unlocked original set' do
      before :each do
        decorated_work_order.original_set = set
        expect(decorated_work_order.original_set).to receive(:create_locked_clone)
          .with(decorated_work_order.name).and_return(locked_set)
      end

      it 'creates a locked clone of the original set' do
        expect(decorated_work_order.finalise_set).to be true
        expect(decorated_work_order.set_uuid).to eq(locked_set.uuid)
      end
    end

  end

  describe '#create_editable_set' do

    context 'when the work order already has an input set' do
      let(:work_order) { create(:work_order, set_uuid: SecureRandom.uuid) }

      it 'raises an exception' do
        expect { decorated_work_order.create_editable_set }.to raise_exception "Work order already has input set"
      end
    end

    context 'when the work order has no original set' do
      it 'raises an exception' do
        expect { decorated_work_order.create_editable_set }.to raise_exception "Work order has no original set"
      end
    end

    context 'when the new set is created' do
      before do
        decorated_work_order.original_set = set
        allow(decorated_work_order.original_set).to receive(:create_unlocked_clone).and_return(locked_set)
      end

      it 'returns the new set' do
        expect(decorated_work_order.create_editable_set).to eq(locked_set)
        expect(decorated_work_order.original_set).to have_received(:create_unlocked_clone).with(work_order.name)
      end
    end
  end

  describe '#jobs' do
    let(:work_order) { build(:work_order, jobs: build_list(:job, 3))}

    it 'returns a collection of Jobs' do
      expect(decorated_work_order.jobs.length).to eql(3)
      expect(decorated_work_order.jobs).to all be_instance_of(Job)
    end
  end

  describe '#work_plan' do
    it 'returns a WorkPlan' do
      expect(decorated_work_order.work_plan).to be_instance_of WorkPlan
    end
  end

end