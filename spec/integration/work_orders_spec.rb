require 'swagger_helper'
require 'securerandom'

require 'support/test_services_helper'

describe 'Work Orders API' do
  include TestServicesHelper

  before do
    webmock_matcon_schema
    allow_set_service_lock_set
  end


  let(:set_for_work_order) { made_up_set }
  let(:catalogue) { create(:catalogue) }
  let(:product) { create(:product, catalogue: catalogue) }

  let(:proposal) { made_up_proposal }

  let(:instance_wo) { 
    create(:work_order, status: WorkOrder.ACTIVE, set_uuid: set_for_work_order.id,
     product: product, proposal_id: proposal.id )
  }
  let(:instance_wo2) { create(:work_order)}

  let(:some_materials) { create(:material)}
  let(:work_order) { 
    json = build(:valid_work_order_completion_message_json) 
    json[:work_order][:work_order_id] = instance_wo.id
    json
  }
  let(:work_order_id) { work_order[:work_order][:work_order_id] }
  
  let(:invalid_work_order) { 
    json = build(:valid_work_order_completion_message_json) 
    json[:work_order][:work_order_id] = instance_wo2.id
    json
  }

  path '/api/v1/work_orders/{work_order_id}' do
    get 'Obtains the information of a work order' do
      tags 'Work Orders'
      produces 'application/json'
      parameter name: :work_order_id, :in => :path, :type => :integer

      response '200', 'work order obtained' do
        let(:work_order_id) { instance_wo.id }
        run_test!
      end      
    end
  end

  path '/api/v1/work_orders/{work_order_id}/complete' do

    post 'Completes a work order' do
      tags 'Work Orders'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :work_order_id, :in => :path, :type => :integer
      parameter name: :work_order, in: :body, 
        schema: JSON.parse(WorkOrderValidatorService.schema_content)      

      response '200', 'work order found' do
        run_test!
      end

      response '422', 'wrong work order specified' do
        let(:work_order) { invalid_work_order }
        run_test!
      end

      response '502', 'the work order could not be updated' do
        before do
          allow(SetClient::Set).to receive(:create).and_raise("a problem")
        end
        run_test!
      end
    end
  end

  path '/api/v1/work_orders/{work_order_id}/cancel' do

    post 'Cancels a work order' do
      tags 'Work Orders'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :work_order_id, :in => :path, :type => :string
      parameter name: :work_order, in: :body, 
        schema: JSON.parse(WorkOrderValidatorService.schema_content)      

      response '200', 'work order found' do
        run_test!
      end

      response '422', 'wrong work order specified' do
        let(:work_order) { invalid_work_order }
        run_test!
      end

      response '502', 'the work order could not be updated' do
        before do
          allow(SetClient::Set).to receive(:create).and_raise("a problem")
        end
        run_test!
      end      
    end
  end

end
