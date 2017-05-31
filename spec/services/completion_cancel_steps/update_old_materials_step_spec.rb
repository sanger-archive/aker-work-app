require 'rails_helper'
require 'support/test_services_helper'
require 'completion_cancel_steps/update_old_materials_step'


RSpec.describe "UpdateOldMaterialsStep" do
  include TestServicesHelper

  def make_step(msg)
    @step = UpdateOldMaterialsStep.new(make_work_order, msg)
  end

  setup do
    @an_id = 'ID1'
    @material_params = { _id: @an_id, a: 1, b: 2 }
    @msg = { 
      :work_order => { 
        :updated_materials => [@material_params]
      }
    }
    @material = make_material
    allow(@material).to receive(:attributes).and_return({})
    allow(@material).to receive(:clone).and_return(make_material)
    @modif_params = @material_params.clone
    @modif_params.delete(:_id)
    allow(@material).to receive(:update_atttributes).with(@modif_params).and_return(true)
    allow(MatconClient::Material).to receive(:find).and_return(@material)
    make_step(@msg)
  end

  context '#up' do
    it 'the materials are updated' do
      allow(@material).to receive(:update_atttributes).and_return(true)
      @step.up
      expect(@material).to have_received(:update_atttributes)
    end
  end

  context '#down' do
  end
end