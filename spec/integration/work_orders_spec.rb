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

end
