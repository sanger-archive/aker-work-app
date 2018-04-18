require 'rails_helper'
require 'support/test_services_helper'
require 'completion_cancel_steps/update_old_materials_step'


RSpec.describe "UpdateOldMaterialsStep" do
  include TestServicesHelper

  def make_step(msg)
    @step = UpdateOldMaterialsStep.new(make_job, msg)
  end

  setup do
    @an_id = 'ID1'
    @material_params = { _id: @an_id, a: 1, b: 2 }
    @msg = { 
      :job => { 
        :updated_materials => [@material_params]
      }
    }

    stub_matcon_material

    @material = make_material
    allow(@material).to receive(:attributes).and_return({})
    allow(@material).to receive(:clone).and_return(make_material)
    @modif_params = @material_params.clone
    @modif_params.delete(:_id)
    allow(@material).to receive(:update_attributes).with(@modif_params).and_return(true)
    allow(MatconClient::Material).to receive(:find).and_return(@material)
    make_step(@msg)
  end

  context '#up' do
    it 'the materials are updated' do
      allow(@material).to receive(:update_attributes).and_return(true)
      @step.up
      expect(@material).to have_received(:update_attributes)
    end
  end

  context '#down' do
    it 'the materials are rollback' do
      attrs = {a:1, b:2}
      allow(@step).to receive(:materials_before_changes).and_return([id: @an_id, attrs: attrs])

      material = make_material

      allow(MatconClient::Material).to receive(:find).and_return(material)
      allow(material).to receive(:update_attributes).and_return(true)
      @step.down
      expect(material).to have_received(:update_attributes).with(attrs)
    end
  end
end