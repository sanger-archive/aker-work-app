require 'rails_helper'
debugger
require 'support/test_services_helper'

require 'completion_cancel_steps/create_containers_step'

RSpec.describe 'CreateContainerStep' do


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
    context 'one of the elements of the list has already an id' do
      before do
        make_step(work_order: {containers: [@data1.merge(_id: 1), @data2]})
      end

      it 'should just create containers without id provided' do
        expect(MatconClient::Container).to receive(:create).with([@data2])
        @step.up
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
    context 'one of the elements of the list has already an id' do
      before do
        make_step(work_order: {containers: [@data1.merge(_id: 1), @data2]})
        @step.up
      end

      it 'should just destroy containers created by #up' do
        expect(MatconClient::Container).to receive(:destroy).with(@step.containers.first.id)
        @step.down
      end
    end    

  end
end