require 'rails_helper'

RSpec.describe WorkOrderDispatcher do

  let(:serializer) { WorkOrderSerializer.new }
  let(:work_order_dispatcher) { WorkOrderDispatcher.new(serializer: serializer) }
  let(:available_material) { double(MatconClient::Material, available: true) }
  let(:unavailable_material) { double(MatconClient::Material, available: false) }
  let(:materials) { [available_material, available_material, available_material] }
  let(:work_plan) { create(:work_plan, product: create(:product), project_id: subproject.id) }
  let(:work_order) { create(:work_order_with_jobs, work_plan: work_plan) }
  let(:project) { make_node(10, 'S1234') }
  let(:subproject) { make_node(11, 'S1234-0', project.id) }

  def make_node(id, cost_code, parent_id=nil)
    node = double(:project, id: id, name: "Project #{id}", cost_code: cost_code, parent_id: parent_id)
    allow(StudyClient::Node).to receive(:find).with(id).and_return([node])
    node
  end

  before :each do
    work_order_dispatcher.work_order = work_order
    allow(work_order_dispatcher).to receive(:materials).and_return(materials)

    allow(UbwClient).to receive(:missing_unit_prices).and_return([])
  end

  describe '#initialize' do

    it 'sets serializer' do
      expect(work_order_dispatcher.serializer).to be(serializer)
    end

  end

  describe 'validation' do
    before :each do
      work_order_dispatcher.work_order = work_order
    end

    context 'when WorkOrder can not be dispatched' do
      let(:work_order) { create(:work_order_with_jobs, status: WorkOrder.BROKEN, work_plan: work_plan) }

      it 'is invalid' do
        expect(work_order_dispatcher.valid?).to be false
        expect(work_order_dispatcher.errors.full_messages_for(:work_order)).to eql(['Work order can not be dispatched'])
      end
    end

    context 'when WorkOrder does not have any Jobs' do
      let(:work_order) { create(:queued_work_order, work_plan: work_plan) }

      it 'is invalid' do
        expect(work_order_dispatcher.valid?).to be false
        expect(work_order_dispatcher.errors.full_messages_for(:work_order)).to eql(['Work order does not have any Jobs'])
      end
    end

    context 'when WorkOrder has invalid modules' do
      let(:invalid_process_module) { build(:process_module, name: 'Invalid') }
      let(:work_order) { create(:work_order_with_jobs, process_modules: [invalid_process_module], work_plan: work_plan) }

      before do
        allow(UbwClient).to receive(:missing_unit_prices) { |module_names, cost_code| module_names }
      end

      it 'is invalid' do
        expect(work_order_dispatcher.valid?).to be false
        expected_error = "Process module could not be validated: #{[invalid_process_module.name]}"
        expect(work_order_dispatcher.errors.full_messages_for(:base)).to eq([expected_error])
      end
    end

    context 'when any Materials are not available' do

      let(:materials) { [available_material, unavailable_material, available_material] }

      it 'is invalid' do
        expect(work_order_dispatcher.valid?).to be false
        expect(work_order_dispatcher.errors.full_messages_for(:materials)).to eql(['Materials are not all available'])
      end
    end

  end

  describe '#dispatch' do

    context 'when invalid' do
      before :each do
        allow(work_order_dispatcher).to receive(:invalid?).and_return(true)
      end

      it 'returns false' do
        expect(work_order_dispatcher.dispatch(work_order)).to be false
      end
    end

    context 'when valid' do

      before :each do
        # It sets materials availability to false
        expect(work_order_dispatcher).to receive(:set_materials_availability).with(false)
        # It serializes the Work Order
        expect(serializer).to receive(:serialize).with(work_order).and_return({})
        # It sends the Work Order to the Lims Client
        expect(LimsClient).to receive(:post).with(work_plan.product.catalogue.job_creation_url, {})
      end

      it 'sets the work_order dispatch_date' do
        expect { work_order_dispatcher.dispatch(work_order) }.to change(work_order, :dispatch_date)
      end

      it 'sets the work_order status to active' do
        expect { work_order_dispatcher.dispatch(work_order) }.to change(work_order, :status).to("active")
      end

      context 'when sending to LIMS fails' do

        before :each do
          expect(work_order_dispatcher).to receive(:set_materials_availability).with(true)
          allow(LimsClient).to receive(:post).and_raise(StandardError, 'Sending to LIMS failed')
        end

        it 'returns false' do
          expect(work_order_dispatcher.dispatch(work_order)).to be false
        end

        it 'sets an error message' do
          work_order_dispatcher.dispatch(work_order)
          expect(work_order_dispatcher.errors.full_messages_for(:base)).to eql(['Sending to LIMS failed'])
        end

      end
    end
  end

end
