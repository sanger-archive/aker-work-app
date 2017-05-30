require 'rails_helper'
require 'support/test_services_helper'
require 'completion_cancel_steps/create_new_materials_step'


RSpec.describe 'CreateNewMaterialsStep' do
  include TestServicesHelper
  def make_step(msg)
    @step = CreateNewMaterialsStep.new(make_work_order, msg)
  end


  before do
    stub_matcon
    @material_params = { a: 1, b: 2 }        
    @num_times = 3    
  end
  context '#up' do
    context 'when no container is provided' do
      before do
        @msg = { 
          :work_order => { 
            :new_materials => @num_times.times.map { @material_params }
          }
        }
        expect(MatconClient::Material).to receive(:create).with(@material_params)
        make_step(@msg)
        @step.up        
      end
      it 'creates the materials' do
        expect(@step.materials.length).to eq(@num_times)
      end
    end
    context 'when the barcode of the container does not exist' do
      before do
        @wrong_barcode = 'wrong'
        @msg = { 
          :work_order => { 
            :new_materials => @num_times.times.map { @material_params.merge({
              container: { barcode: @wrong_barcode}
              }) }
          }
        }        
        expect(MatconClient::Container).to receive(:where).with(barcode: @wrong_barcode).and_return([])
        make_step(@msg)
      end
      it 'fails the step' do
        expect { @step.up }.to raise_exception
      end
    end
    context 'when the container exists' do
      before do
        @good_barcode = 'good'
        @msg = { 
          :work_order => { 
            :new_materials => @num_times.times.map {|pos| @material_params.merge({
              container: { barcode: @good_barcode, address: pos }
              }) }
          }
        }
        @container_mock = make_container
        expect(MatconClient::Container).to receive(:where).with(barcode: @good_barcode).and_return([@container_mock])
        make_step(@msg)
      end

      it 'creates the material' do
        allow(@container_mock).to receive(:add_to_slot)
        @step.up        
        expect(@step.materials.length).to eq(@num_times)
      end
      context 'when the material is in the slot of a container' do
        it 'adds the material to the slot' do
          debugger
          @num_times.times.each do |i|
            expect(@container_mock).to receive(:add_to_slot).with(i, @step.materials[i])
          end
          @step.up
        end
      end
      context 'when the material is in a container' do
        it 'adds the material to the container' do
          @num_times.times.each do |i|
            expect(@container_mock).to receive(:material_id=).with(@step.materials[i])
          end
          @step.up
        end
      end
    end
  end
  context '#down' do
    context 'when some containers were created' do
      it 'restores the containers to the original values' do
        pending
      end
    end
    it 'destroys the materials created' do
      pending
    end
  end
end