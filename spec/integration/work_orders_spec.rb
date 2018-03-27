# frozen_string_literal: true

require 'rails_helper'
require 'swagger_helper'
require 'securerandom'

require 'support/test_services_helper'

describe 'Work Orders API' do
  include TestServicesHelper

  before do
    webmock_billing_facade_client
    webmock_matcon_schema
    allow_set_service_lock_set
    allow_broker_connection
  end

  let(:set_for_work_order) { made_up_set }
  let(:catalogue) { create(:catalogue) }
  let(:product) { create(:product, catalogue: catalogue) }

  let(:project) { make_node('my project', 'S0001', 1, 0, false, true) }
  let(:proposal) { make_node('my proposal', 'S0001-0', 2, project.id, true, false) }

  let(:work_plan) { create(:work_plan, product: product, project_id: proposal.id) }

  let(:instance_wo) do
    create(:work_order, status: WorkOrder.ACTIVE,
                        set_uuid: set_for_work_order.id,
                        work_plan: work_plan)
  end

  let(:instance_wo2) { create(:work_order) }

  let(:work_order) do
    json = build(:valid_work_order_completion_message_json)
    json[:work_order][:work_order_id] = instance_wo.id
    json
  end

  let(:work_order_id) { work_order[:work_order][:work_order_id] }

  let(:invalid_work_order) do
    json = build(:valid_work_order_completion_message_json)
    json[:work_order][:work_order_id] = instance_wo2.id
    json
  end

  path '/api/v1/work_orders/{work_order_id}' do
    get 'Obtains the information of a work order' do
      tags 'Work Orders'
      produces 'application/json'
      parameter name: :work_order_id, in: :path, type: :integer

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
      parameter name: :work_order_id, in: :path, type: :integer
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
          expect_any_instance_of(LockSetStep).to receive(:up).and_raise('error')
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
      parameter name: :work_order_id, in: :path, type: :string
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
          expect_any_instance_of(LockSetStep).to receive(:up).and_raise('error')
        end
        run_test!
      end
    end
  end
end
