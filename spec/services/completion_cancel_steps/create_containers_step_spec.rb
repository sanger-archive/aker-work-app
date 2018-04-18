require 'rails_helper'
require 'support/test_services_helper'

require 'completion_cancel_steps/create_containers_step'

RSpec.describe 'CreateContainerStep' do
  include TestServicesHelper

  let(:no_result) { double('no results', first: nil) }

  let(:print_count) do
    { print_count: 0 }
  end

  let(:containers) { ['ABC-123', 'XYZ-123'].map { |bc| make_data(bc) } }

  def make_step(msg)
    @step = CreateContainersStep.new(make_work_order, msg)
  end

  def load_container(c)
    allow(MatconClient::Container).to receive(:where).with(barcode: c[:barcode]).and_return(double('results', first: c))
  end

  def make_data(barcode)
    { barcode: barcode, num_of_rows: 1, num_of_cols: 1, row_is_alpha: false, col_is_alpha: false }
  end

  before do
    stub_matcon
    allow(MatconClient::Container).to receive(:where).and_return(no_result)
  end

  describe '#up' do
    context 'when no containers are requested' do
      before do
        make_step(job: {containers: []})        
        @step.up
      end
      it 'should not have created any containers' do
        expect(MatconClient::Container).not_to have_received(:create)
      end
      it 'should store an empty array in the new_containers attribute' do
        expect(@step.new_containers).to be_empty
      end
    end
    context 'when new containers are requested' do
      before do
        make_step(job: {containers: containers})
        @step.up
      end
      it 'should have called create with the appropriate arguments' do
        expect(MatconClient::Container).to have_received(:create).with(containers.map { |c| c.merge(print_count) })
      end
      it 'should have stored the containers in the new_containers attribute' do
        expect(@step.new_containers.length).to eq(2)
      end
    end

    context 'when containers already exist' do
      before do
        containers.each { |c| load_container(c) }
        make_step(job: {containers: containers})
        @step.up
      end

      it 'should not create containers' do
        expect(MatconClient::Container).not_to have_received(:create)
      end
      it 'should have stored no new containers' do
        expect(@step.new_containers).to be_empty
      end
    end

    context 'when containers partially already exist' do
      before do
        load_container(containers.first)
        make_step(job: {containers: containers})
        @step.up
      end

      it 'should create the new container' do
        expect(MatconClient::Container).to have_received(:create).once
        expect(MatconClient::Container).to have_received(:create).with([containers.second.merge(print_count)])
        expect(MatconClient::Container).not_to have_received(:create).with([containers.first.merge(print_count)])
      end
      it 'should have stored 1 new container' do
        expect(@step.new_containers.length).to eq(1)
      end
    end
  end

  describe '#down' do
    context 'when there are no containers to destroy' do
      before do
        make_step(job: {containers: []})
        @step.instance_variable_set(:@new_containers, [])
        @step.down
      end
      it 'should not have destroyed any containers' do
        # Also shouldn't have called destroy on any instance of Container,
        # but there are none available to call destroy on, so nothing to assert
        expect(MatconClient::Container).not_to have_received(:destroy)
      end
    end
    context 'when there are containers to destroy' do
      before do
        make_step(job: {containers: containers})
        @step.up
        @created_containers = @step.new_containers.clone
        @created_containers.each { |c| allow(c).to receive(:destroy) }
        @step.down
      end
      it 'should destroy all the containers created' do
        @created_containers.each do |c|
          expect(c).to have_received(:destroy)
        end
      end
      it 'should remove the containers the new_containers array' do
        expect(@step.new_containers).to be_empty
      end
    end
  end
end