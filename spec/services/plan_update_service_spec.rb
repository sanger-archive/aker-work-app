require 'rails_helper'

RSpec.describe :plan_update_service do
  let(:user_and_groups) { ['user@sanger.ac.uk', 'world'] }
  let(:messages) { {} }
  let(:params) { {} }
  let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0]) }
  let(:service) do
    ps = PlanUpdateService.new(params, plan, user_and_groups, messages)
    allow(ps).to receive(:helper).and_return helper
    ps
  end
  let(:unit_price) { 11 }
  let(:helper) do
    h = instance_double("PlanHelper")
    allow(h).to receive(:check_product_options).and_return true
    allow(h).to receive(:validate_project_selection).and_return true
    allow(h).to receive(:validate_data_release_strategy_selection).and_return true
    allow(h).to receive(:check_set_contents).and_return true
    allow(h).to receive(:predict_unit_price).and_return unit_price
    h
  end

  let(:set) { make_set(2, true) }

  let(:known_materials) do
    known_mats = {}
    allow(MatconClient::Material).to receive(:where) do |args|
      matids = args['_id']['$in']
      make_rs_response(matids.map { |id| known_mats[id] }.compact)
    end
    known_mats
  end

  before do
    setup
    @result = service.perform
  end

  def extra_setup
  end

  def setup
    stub_stamps
    extra_setup
  end

  describe 'selecting a set' do
    let(:params) { { original_set_uuid: set.id } }

    context 'when the set is suitable' do
      it 'should return true' do
        expect(@result).to be_truthy
      end

      it 'should have no errors' do
        expect(messages[:error]).to be_nil
      end

      it 'should have set the set id in the work plan' do
        expect(plan.reload.original_set_uuid).to eq(set.id)
      end
    end

    context 'when the plan already has a set selected' do
      let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0], original_set_uuid: SecureRandom.uuid) }
      it 'should return true' do
        expect(@result).to be_truthy
      end

      it 'should have no errors' do
        expect(messages[:error]).to be_nil
      end

      it 'should have set the new set id in the work plan' do
        expect(plan.reload.original_set_uuid).to eq(set.id)
      end
    end

    context 'when the set contents are not permitted' do
      def extra_setup
        allow(helper).to receive(:check_set_contents).with(set.id) do
          messages[:error] = "The set contents were wrong."
          false
        end
      end

      it 'should return false' do
        expect(@result).to be_falsey
      end

      it 'should have the error message from the helper' do
        expect(messages[:error]).to eq "The set contents were wrong."
      end

      it 'should not have set the new set id in the work plan' do
        expect(plan.reload.original_set_uuid).to be_nil
      end
    end

  end

  describe 'selecting a project id' do
    let(:plan) { WorkPlan.create!(owner_email: user_and_groups[0], original_set_uuid: set.id) }
    let(:project_id) { 20 }
    let(:params) { { project_id: project_id } }

    context 'when the project is set successfully' do
      it 'should return true' do
        expect(@result).to be_truthy
      end

      it 'should have no errors' do
        expect(messages[:error]).to be_nil
      end

      it 'should have set the project id in the work plan' do
        expect(plan.reload.project_id).to eq(project_id)
      end

      it 'should not have set the estimated cost on the plan' do
        expect(plan.reload.estimated_cost).to be_nil
      end
    end

    context 'when the plan has a product and options already selected' do
      # TODO - setup
      it 'should return true' do
        expect(@result).to be_truthy
      end

      it 'should have no errors' do
        expect(messages[:error]).to be_nil
      end

      it 'should have set the project id in the work plan' do
        expect(plan.reload.project_id).to eq(project_id)
      end

      it 'should not have set the estimated cost on the plan' do
        expect(plan.reload.estimated_cost).to eq(unit_price * set.meta[:size])
      end

    end

  end







  def stub_stamps
    allow(StampClient::Permission).to receive(:check_catch).and_return true
  end

  def make_set(size=1, available=true)
    uuid = SecureRandom.uuid
    set = double(:set, id: uuid, uuid: uuid, name: "Set #{uuid}", locked: false, meta: { size: size })

    if size==0
      matids = []
      set_materials = double(:set_materials, materials: [])
    else
      matids = (0...size).map { SecureRandom.uuid }
      set_content_materials = matids.map { |matid| double(:material, id: matid) }
      set_materials = double(:set_materials, materials: set_content_materials)
      materials = matids.map { |matid| double(:material, id: matid, attributes: { 'available' => available }) }

      materials.each { |material| known_materials[material.id] = material }
    end

    allow(SetClient::Set).to receive(:find_with_materials).with(uuid).and_return([set_materials])
    allow(SetClient::Set).to receive(:find).with(uuid).and_return([set])
    allow(set).to receive(:_material_uuids).and_return(matids)
    set
  end

  def make_rs_response(items)
    result_set = double(:result_set, to_a: items.to_a, has_next?: false)
    return double(:response, result_set: result_set)
  end
end