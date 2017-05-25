require 'rails_helper'
require 'completion_cancel_steps/create_containers_step'

RSpec.describe 'CreateContainerStep' do

  def make_slots
    'A:1 A:2 A:3 B:1 B:2 B:3'.split.map do |address|
      slot = double('slot', address: address)
      allow(slot).to receive(:material_id=)
      slot
    end
  end

  def made_up_barcode
    @barcode_counter += 1
    "AKER-#{@barcode_counter}"
  end

  def made_up_uuid
    SecureRandom.uuid
  end

  def make_container
    container = double("container", slots: make_slots, barcode: made_up_barcode, id: made_up_uuid)
    allow(container).to receive(:save)
    container
  end

  def stub_matcon
    @barcode_counter = 0
    @containers = []

    allow(MatconClient::Container).to receive(:destroy).and_return(true)

    allow(MatconClient::Container).to receive(:create) do |args|
      [args].flatten.map do
        container = make_container
        @containers.push(container)
        container
      end
    end
  end

  def make_work_order
    @work_order = double(:work_order)
  end

  def make_step(msg)
    @step = CreateContainersStep.new(make_work_order, msg)
  end

  before do
    @data1 = {a:1, b:2, print_count: 0}
    @data2 = {c:3, d:4, print_count: 0}

    stub_matcon
  end

  context '#up' do
    context 'when no containers are requested' do
      before do
        make_step(work_order: {containers: []})        
      end
      it 'should not create any containers' do
        expect(MatconClient::Container).not_to receive(:create)
        @step.up
      end
      it 'should store an empty array in the @containers attribute' do
        @step.up
        expect(@step.containers).to eq([])
      end
    end
    context 'when a list of containers creation is requested ' do
      before do
        make_step(work_order: {containers: [@data1, @data2]})
      end

      it 'should have call create with the appropriate arguments' do
        expect(MatconClient::Container).to receive(:create).with([@data1, @data2])
        @step.up
      end
      it 'should have stored the containers in the @containers attribute to be able to roll them back' do
        @step.up
        expect(@step.containers.length).to eq(2)
      end
    end
  end
  context '#down' do
    context 'when no containers were created before' do
      before do
        make_step(work_order: {containers: []})
        @step.up
      end
      it 'should not destroy any container' do
        expect(MatconClient::Container).not_to receive(:destroy)
        @step.down
      end
    end
    context 'when some containers were created' do
      before do
        make_step(work_order: {containers: [@data1, @data2]})
        @step.up
      end
      it 'should destroy all the containers created' do
        expect(MatconClient::Container).to receive(:destroy).with(@step.containers[0].id)
        expect(MatconClient::Container).to receive(:destroy).with(@step.containers[1].id)
        @step.down        
      end
    end
  end
end