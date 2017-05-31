require 'rails_helper'
require 'support/test_services_helper'
require 'completion_cancel_steps/create_new_materials_step'


RSpec.describe 'CreateNewMaterialsStep' do
  include TestServicesHelper

  # def stub_matcon
  #   @barcode_counter = 0
  #   @materials = []

  #   allow(MatconClient::Material).to receive(:destroy).and_return(true)

  #   allow(MatconClient::Material).to receive(:create) do |args|
  #     [args].flatten.map do
  #       material = make_material
  #       @materials.push(material)
  #       material
  #     end
  #   end
  # end


  def make_step(msg)
    @work_order = make_work_order
    @step = CreateNewMaterialsStep.new(@work_order, msg)
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
              container: { barcode: @good_barcode, address: "A:1" }
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
      context 'when the material is in the slot of a container (PLATE)' do
        it 'adds the material to the slot' do
          # mocks MatconClient to always return the same material so we can compare easily with it
          material = make_material
          allow(material).to receive(:to_a).and_return([material])
          allow(MatconClient::Material).to receive(:create).and_return(material)
          @step.up
        end
      end
      context 'when the material is in a container (TUBE)' do
        before do
          @msg = { 
          :work_order => { 
            :new_materials => @num_times.times.map {|pos| @material_params.merge({
              container: { barcode: @good_barcode }
              }) }
          }
        }
        make_step(@msg)        
        end
        it 'adds the material to the container' do          
          material = make_material
          allow(material).to receive(:to_a).and_return([material])
          allow(MatconClient::Material).to receive(:create).and_return(material)
          @step.up
        end
      end
    end
  end
  context '#down' do
    before do
      @good_barcode = 1
      @msg = { 
        :work_order => { 
            :new_materials => @num_times.times.map {|pos| @material_params.merge({
              container: { barcode: @good_barcode }
              }) }
        }
      }

      make_step(@msg)
      @container = make_container
      @material = make_material
      allow(@step).to receive(:materials).and_return([@material])
      allow(@step).to receive(:modified_containers).and_return([@container])

      allow(MatconClient::Container).to receive(:find).and_return(@container)
      allow(@container).to receive(:serialize).and_return('serialized')
      allow(@container).to receive(:update_attributes).and_return(true)      
    end

    it 'restores the containers to the original values' do
      expect(@container).to receive(:save)
      @step.down

    end
    it 'destroys the materials created' do
      @step.down
      expect(MatconClient::Material).to have_received(:destroy).once
    end
  end
end