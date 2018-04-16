# frozen_string_literal: true

require 'rails_helper'
require 'swagger_helper'
# require 'securerandom'

require 'support/test_services_helper'

describe 'Jobs API' do
  include TestServicesHelper

  before do
    webmock_matcon_schema
    allow_broker_connection
    stub_matcon
  end

  let(:catalogue) { create(:catalogue) }
  let(:product) { create(:product, catalogue: catalogue) }

  let(:project) { make_node('my project', 'S0001', 1, 0, false, true) }
  let(:proposal) { make_node('my proposal', 'S0001-0', 2, project.id, true, false) }

  let(:set_for_work_order) { made_up_set }

  let(:work_plan) { create(:work_plan, product: product, project_id: proposal.id) }

  let(:work_order) do
    create(:work_order, status: WorkOrder.ACTIVE,
                        set_uuid: set_for_work_order.id,
                        work_plan: work_plan)
  end

  let(:container) { make_container }

  let(:queued_job) do
    create(:job, work_order: work_order, container_uuid: container.id)
  end

  let(:started_job) do
    create(:job, work_order: work_order, started: Time.now)
  end

  let(:completed_job) do
    create(:job, work_order: work_order, started: Time.now, completed: Time.now)
  end

  let(:cancelled_job) do
    create(:job, work_order: work_order, started: Time.now, cancelled: Time.now)
  end

  let(:queue_job_msg) do
    json = build(:valid_job_completion_message_json)
    json[:job][:job_id] = queued_job.id
    json
  end

  let(:start_job_msg) do
    json = build(:valid_job_completion_message_json)
    json[:job][:job_id] = started_job.id
    json
  end

  let(:complete_job_msg) do
    json = build(:valid_job_completion_message_json)
    json[:job][:job_id] = completed_job.id
    json
  end

  let(:cancel_job_msg) do
    json = build(:valid_job_completion_message_json)
    json[:job][:job_id] = cancelled_job.id
    json
  end

  path '/api/v1/jobs/{job_id}' do
    get 'Obtains the information of a job that exists' do

      parameter name: :job_id, in: :path, type: :integer

      response '200', 'job obtained' do
        let(:job_id) { queued_job.id }
        run_test!
      end
    end
  end

  path '/api/v1/jobs/{job_id}/start' do
    put 'Starts a job' do

      consumes 'application/json'
      produces 'application/json'
      parameter name: :job_id, in: :path, type: :integer
      parameter name: :job, in: :body,
                schema: JSON.parse(JobValidatorService.schema_content)

      response '200', 'job started' do
        let(:job_id) { queued_job.id }
        let(:job) { queue_job_msg }
        run_test!
      end

      response '422', 'job already started' do
        let(:job_id) { started_job.id }
        let(:job) { start_job_msg }
        run_test!
      end

    end
  end

  path '/api/v1/jobs/{job_id}/complete' do
    put 'Completes a job' do
      consumes 'application/json'
      produces 'application/json'
      parameter name: :job_id, in: :path, type: :integer
      parameter name: :job, in: :body,
                schema: JSON.parse(JobValidatorService.schema_content)

      response '200', 'job completed' do
        let(:job_id) { started_job.id }
        let(:job) { start_job_msg }
        run_test!
      end

      response '422', 'job already cancelled' do
        let(:job_id) { completed_job.id }
        let(:job) { complete_job_msg }
        run_test!
      end
    end
  end

  path '/api/v1/jobs/{job_id}/cancel' do
    put 'Cancels a work order' do

      consumes 'application/json'
      produces 'application/json'
      parameter name: :job_id, in: :path, type: :string
      parameter name: :job, in: :body,
                schema: JSON.parse(JobValidatorService.schema_content)

      response '200', 'job cancelled' do
        let(:job_id) { started_job.id }
        let(:job) { start_job_msg }
        run_test!
      end

      response '422', 'job already cancelled' do
        let(:job_id) { cancelled_job.id }
        let(:job) { cancel_job_msg }
        run_test!
      end

    end
  end
end
