require 'rails_helper'
require 'support/test_services_helper'
require 'completion_cancel_steps/lock_set_step'

RSpec.describe 'LockSetStep' do
  include TestServicesHelper

  def make_step(msg, materials)
    @work_order = make_work_order
    material_step = double('material_step', materials: materials)
    @step = LockSetStep.new(@work_order, msg, material_step)
  end

  setup do
    stub_matcon
    @work_order = make_work_order
    @finished_set = instance_double('set', locked: false, owner_id: @work_order.user.email, id: made_up_uuid)
    

    allow(SetClient::Set).to receive(:create).and_return(@finished_set)
    allow(@finished_set).to receive(:set_materials)
    allow(@finished_set).to receive(:update_attributes!)

    stub_matcon

    @materials = [make_material]
    make_step({}, @materials)
  end

  context '#up' do
    it 'updates the set' do
      expect(@work_order).to receive(:update_attributes!).with(finished_set_uuid: @finished_set.id)
      expect(@finished_set).to receive(:set_materials).with(@materials.map(&:id))
      expect(@finished_set).to receive(:update_attributes).with(owner_id: @work_order.user.email, locked: true)
      @step.up        
    end
  end

  context '#down' do
    it 'sets the finished set uuid to nil' do
      allow(@work_order).to receive(:finished_set_uuid).and_return(true)
      expect(@work_order).to receive(:update_attributes).with(finished_set_uuid: nil)
      @step.down
    end
  end
end