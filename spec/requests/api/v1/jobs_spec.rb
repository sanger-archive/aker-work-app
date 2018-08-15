# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Jobs', type: :request do
  include TestServicesHelper
  let(:headers) do
    {
      'Content-Type' => 'application/vnd.api+json',
      'Accept' => 'application/vnd.api+json'
    }
  end
  let(:params) do
    {
      job: {
        job_id: job.id
      }
    }.to_json
  end
  let(:input_set) { double(SetClient::Set, uuid: SecureRandom.uuid, meta: { size: 10 })}

  def mock_set_creation
    mocked_set = double('set', id: 'some_id')
    allow(mocked_set).to receive(:update_attributes)
    allow(mocked_set).to receive(:set_materials)
    allow(SetClient::Set).to receive(:create).and_return(mocked_set)
  end

  before do
    Timecop.freeze(Time.now)
    webmock_matcon_schema
    stub_matcon
  end

  describe 'Resource' do
    context 'GET' do
      let(:set_for_work_order) { made_up_set }
      let(:yesterday) { Time.now.yesterday }
      let(:project) { make_node('my project', 'S0001', 1, 0, false, true) }
      let(:catalogue) { create(:catalogue) }
      let(:product) { create(:product, catalogue: catalogue) }
      let(:plan) do
        create :work_plan,
               owner_email: 'owner@here.com',
               project_id: project.id,
               product_id: product.id,
               comment: 'a comment'
      end
      let(:order) do
        create :work_order,
               set_uuid: set_for_work_order.id,
               dispatch_date: yesterday,
               work_plan_id: plan.id
      end
      let(:container) { make_container }
      let(:job_model) { create :job, work_order: order, container_uuid: container.id, input_set_uuid: input_set.uuid }
      let(:job) { job_model.decorate }

      before do
        allow_any_instance_of(JobDecorator).to receive(:input_set_size).and_return(10)
        get api_v1_job_path(job), headers: headers
      end
      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'conforms to the JSON API schema' do
        expect(response).to match_api_schema('jsonapi')
      end

      it 'returns the info for the job' do
        obtained_job = JSON.parse(response.body)
        expect(obtained_job['data']['id']).to eq(job.id.to_s)
        expect(obtained_job['data']['attributes']['uuid']).to eq(job.uuid)
        expect(obtained_job['data']['attributes']['work-order-id']).to eq(job.work_order_id)
        expect(obtained_job['data']['attributes']['container-uuid']).to eq(container.id)
        expect(obtained_job['data']['attributes']['started']).to eq(nil)
        expect(obtained_job['data']['attributes']['completed']).to eq(nil)
        expect(obtained_job['data']['attributes']['cancelled']).to eq(nil)
        expect(obtained_job['data']['attributes']['broken']).to eq(nil)
        expect(obtained_job['data']['attributes']['date-requested'].to_datetime.to_i)
          .to eq(order.dispatch_date.to_datetime.to_i)
        expect(obtained_job['data']['attributes']['requested-by']).to eq(plan.owner_email)
        expect(obtained_job['data']['attributes']['project-and-costcode'])
          .to eq(project.name + " (#{project.cost_code})")
        expect(obtained_job['data']['attributes']['product']).to eq(plan.product.name)
        expect(obtained_job['data']['attributes']['process-modules']).to eq('')
        expect(obtained_job['data']['attributes']['process']).to eq(job.work_order.process.name)
        expect(obtained_job['data']['attributes']['batch-size']).to eq(10)
        expect(obtained_job['data']['attributes']['work-plan-comment']).to eq(plan.comment)
        expect(obtained_job['data']['attributes']['priority']).to eq(plan.priority)
        expect(obtained_job['data']['attributes']['barcode']).to eq(container.barcode)
        expect(obtained_job['data']['attributes']['set_uuid']).to eq(job.set_uuid)
        expect(obtained_job['data']['attributes']['input-set-uuid']).to eq(job.input_set_uuid)
      end
    end

    context 'PUT' do
      before do
        allow(BrokerHandle).to receive(:working?).and_return(true)
      end
      let(:set_for_work_order) { made_up_set }
      let(:order) { create :work_order, set_uuid: set_for_work_order.id, status: WorkOrder.ACTIVE }
      let(:container) { make_container }
      let(:job) { create :job, work_order: order, container_uuid: container.id }

      it 'does not update the job when receiving params' do
        body = {
          data: {
            type: 'jobs',
            attributes: {
              started: Time.zone.now
            }
          }
        }.to_json
        put api_v1_job_path(job), headers: headers, params: body
        job.reload
        expect(job.started).to eq(nil)
      end

      describe '#start' do
        context 'when job is queued' do
          before do
            put api_v1_job_start_path(job), headers: headers, params: params
          end

          it 'returns a 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'conforms to the JSON API schema' do
            expect(response).to match_api_schema('jsonapi')
          end

          it 'sets the status to active' do
            job.reload
            expect(job.status).to eq('active')
          end
        end
        context 'when job is active' do
          before do
            job.start!
            put api_v1_job_start_path(job), headers: headers, params: params
          end

          it 'returns a failure' do
            expect(response).to have_http_status(:unprocessable_entity)
          end

          it 'does not change the status' do
            job.reload
            expect(job.status).to eq('active')
          end
        end
      end

      describe '#complete' do
        before do
          allow(BillingFacadeClient).to receive(:send_event)

          mock_set_creation
        end
        context 'when job is active' do
          before do
            job.start!
          end

          context 'when the broker is broken' do
            before do
              allow(BrokerHandle).to receive(:working?).and_return(false)
              put api_v1_job_complete_path(job), headers: headers, params: params
            end
            it 'should have correct message in response body' do
              'RabbitMQ broker is broken'
            end
          end

          context 'when the broker is working' do
            before do
              put api_v1_job_complete_path(job), headers: headers, params: params
            end

            it 'returns a 200' do
              expect(response).to have_http_status(:ok)
            end

            it 'conforms to the JSON API schema' do
              expect(response).to match_api_schema('jsonapi')
            end

            it 'sets the status to complete' do
              job.reload
              expect(job.status).to eq('completed')
            end

            it { expect(response).to have_http_status(:ok) }

            it 'should have correct message in repsonse body' do
              msg = 'Your job is completed'
              expect(response.body).to eq({ meta: { message: msg } }.to_json)
            end
          end
        end
        context 'when job is queued' do
          before do
            put api_v1_job_complete_path(job), headers: headers, params: params
          end

          it 'returns a failure' do
            expect(response).to have_http_status(:unprocessable_entity)
          end

          it 'conforms to the JSON API schema' do
            expect(response).to match_api_schema('jsonapi')
          end

          it 'does not change the status' do
            job.reload
            expect(job.status).to eq('queued')
          end
        end
        context 'when job is completed' do
          before do
            job.start!
            job.complete!
            put api_v1_job_complete_path(job), headers: headers, params: params
          end

          it 'returns a failure' do
            expect(response).to have_http_status(:unprocessable_entity)
          end

          it 'conforms to the JSON API schema' do
            expect(response).to match_api_schema('jsonapi')
          end

          it 'does not change the status' do
            job.reload
            expect(job.status).to eq('completed')
          end
        end
      end

      describe '#cancel' do
        before do
          allow(BillingFacadeClient).to receive(:send_event)

          mock_set_creation

        end
        context 'when job is active' do
          before do
            job.start!
            put api_v1_job_cancel_path(job), headers: headers, params: params
          end

          it 'returns a 200' do
            expect(response).to have_http_status(:ok)
          end

          it 'conforms to the JSON API schema' do
            expect(response).to match_api_schema('jsonapi')
          end

          it 'sets the status to cancelled' do
            job.reload
            expect(job.status).to eq('cancelled')
          end
        end
        context 'when job is queued' do
          before do
            put api_v1_job_cancel_path(job), headers: headers, params: params
          end

          it 'returns a failure' do
            expect(response).to have_http_status(:unprocessable_entity)
          end

          it 'does not change the status' do
            job.reload
            expect(job.status).to eq('queued')
          end

          it 'conforms to the JSON API schema' do
            expect(response).to match_api_schema('jsonapi')
          end
        end
        context 'when job is cancelled' do
          before do
            job.start!
            job.cancel!
            put api_v1_job_cancel_path(job), headers: headers, params: params
          end

          it 'returns a failure' do
            expect(response).to have_http_status(:unprocessable_entity)
          end

          it 'does not change the status' do
            job.reload
            expect(job.status).to eq('cancelled')
          end

          it 'conforms to the JSON API schema' do
            expect(response).to match_api_schema('jsonapi')
          end
        end
      end
    end

    describe '#filter[status]' do
      let(:catalogue) { create(:catalogue) }
      let(:product) { create(:product, catalogue: catalogue) }

      let(:project) { make_node('my project', 'S0001', 1, 0, false, true) }
      let(:work_plan) { create(:work_plan, product: product, project_id: project.id) }

      let(:work_order1) { create(:work_order, set_uuid: made_up_set.id, work_plan: work_plan) }
      let(:work_order2) { create(:work_order, set_uuid: made_up_set.id, work_plan: work_plan) }
      let(:work_order3) { create(:work_order, set_uuid: made_up_set.id, work_plan: work_plan) }
      let(:work_order4) { create(:work_order, set_uuid: made_up_set.id, work_plan: work_plan) }

      let(:container) { make_container }
      let(:started_time) { Time.zone.now }

      let!(:queued_job) { create(:job, work_order: work_order1, container_uuid: container.id) }
      let!(:started_job) do
        create :job,
               work_order: work_order2,
               started: started_time,
               container_uuid: container.id
      end
      let!(:completed_job) do
        create :job,
               work_order: work_order3,
               started: started_time,
               completed: Time.zone.now,
               container_uuid: container.id
      end
      let!(:cancelled_job) do
        create :job,
               work_order: work_order4,
               started: started_time,
               cancelled: Time.zone.now,
               container_uuid: container.id
      end

      context 'when filtering by many statuses' do
        before do
          get api_v1_jobs_path, headers: headers, params: { 'filter[status]': 'queued,active' }
        end

        it 'returns a 500' do
          expect(response).to have_http_status(:internal_server_error)
        end
      end

      context 'when filtering by queued jobs' do
        before do
          get api_v1_jobs_path, headers: headers, params: { 'filter[status]': 'queued' }
        end

        it 'returns a 200' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns a list of queued jobs' do
          body = JSON.parse(response.body)
          expect(body['data'][0]['id']).to eq queued_job.id.to_s
          expect(body['data'][0]['attributes']['started']).to eq queued_job.started
          expect(body['data'][0]['attributes']['completed']).to eq queued_job.completed
          expect(body['data'][0]['attributes']['cancelled']).to eq queued_job.cancelled
          expect(body['data'][0]['attributes']['broken']).to eq queued_job.broken
          expect(body['data'][0]['attributes']['work-order-id']).to eq queued_job.work_order.id
          expect(body['meta']['record-count']).to eq 1
        end

        it 'conforms to the JSON API schema' do
          expect(response).to match_api_schema('jsonapi')
        end
      end

      context 'when filtering by active jobs' do
        before do
          get api_v1_jobs_path, headers: headers, params: { 'filter[status]': 'active' }
        end

        it 'returns a 200' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns a list of active jobs' do
          body = JSON.parse(response.body)
          expect(body['data'][0]['id']).to eq started_job.id.to_s
          expect(Date.iso8601(body['data'][0]['attributes']['started']))
            .to be_within(1)
            .of(started_job.started.to_datetime)
          expect(body['data'][0]['attributes']['completed']).to eq started_job.completed
          expect(body['data'][0]['attributes']['cancelled']).to eq started_job.cancelled
          expect(body['data'][0]['attributes']['broken']).to eq started_job.broken
          expect(body['data'][0]['attributes']['work-order-id']).to eq started_job.work_order.id
        end

        it 'conforms to the JSON API schema' do
          expect(response).to match_api_schema('jsonapi')
        end
      end

      context 'when filtering by concluded jobs' do
        before do
          get api_v1_jobs_path, headers: headers, params: { 'filter[status]': 'concluded' }
        end

        it 'returns a 200' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns a list of concluded jobs' do
          body = JSON.parse(response.body)
          expect(body['data'].length).to eq 2
          expect(body['data'][0]['id']).to eq completed_job.id.to_s
          expect(Date.iso8601(body['data'][0]['attributes']['started']))
            .to be_within(1)
            .of(completed_job.started.to_datetime)
          expect(Date.iso8601(body['data'][0]['attributes']['completed']))
            .to be_within(1)
            .of(completed_job.completed.to_datetime)
          expect(body['data'][0]['attributes']['cancelled']).to eq completed_job.cancelled
          expect(body['data'][0]['attributes']['broken']).to eq completed_job.broken
          expect(body['data'][0]['attributes']['work-order-id']).to eq completed_job.work_order.id
          expect(body['data'][1]['id']).to eq cancelled_job.id.to_s
          expect(Date.iso8601(body['data'][1]['attributes']['started']))
            .to be_within(1)
            .of(cancelled_job.started.to_datetime)
          expect(body['data'][1]['attributes']['completed']).to eq cancelled_job.completed
          expect(Date.iso8601(body['data'][1]['attributes']['cancelled']))
            .to be_within(1)
            .of(cancelled_job.cancelled.to_datetime)
          expect(body['data'][1]['attributes']['broken']).to eq cancelled_job.broken
          expect(body['data'][1]['attributes']['work-order-id']).to eq cancelled_job.work_order.id
        end

        it 'conforms to the JSON API schema' do
          expect(response).to match_api_schema('jsonapi')
        end
      end

      context 'when filtering by an unknown status' do
        before do
          get api_v1_jobs_path, headers: headers, params: { 'filter[status]': 'unknown' }
        end

        it 'returns a 500' do
          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end

    describe '#filter[lims]' do
      let(:catalogue) { create(:catalogue) }
      let(:product) { create(:product, catalogue: catalogue) }

      let(:project) { make_node('my project', 'S0001', 1, 0, false, true) }
      let(:work_plan) { create(:work_plan, product: product, project_id: project.id) }

      let(:work_order1) { create(:work_order, set_uuid: made_up_set.id, work_plan: work_plan) }
      let(:work_order2) { create(:work_order, set_uuid: made_up_set.id, work_plan: work_plan) }
      let(:work_order3) { create(:work_order, set_uuid: made_up_set.id, work_plan: work_plan) }
      let(:work_order4) { create(:work_order, set_uuid: made_up_set.id, work_plan: work_plan) }

      let(:container) { make_container }
      let(:started_time) { Time.zone.now }

      let!(:queued_job) { create(:job, work_order: work_order1, container_uuid: container.id) }
      let!(:started_job) do
        create :job,
               work_order: work_order2,
               started: started_time,
               container_uuid: container.id
      end
      let!(:completed_job) do
        create :job,
               work_order: work_order3,
               started: started_time,
               completed: Time.zone.now,
               container_uuid: container.id
      end
      let!(:cancelled_job) do
        create :job,
               work_order: work_order4,
               started: started_time,
               cancelled: Time.zone.now,
               container_uuid: container.id
      end

      context 'when filtering by valid lims id' do
        before do
          get api_v1_jobs_path, headers: headers, params: { 'filter[lims]': 'the LIMS' }
        end

        it 'returns a 200' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns a list of jobs' do
          body = JSON.parse(response.body)
          expect(body['data'].length).to eq 4
        end
      end

      context 'when filtering by invalid lims id' do
        before do
          get api_v1_jobs_path, headers: headers, params: { 'filter[lims]': 'unknown LIMS' }
        end

        it 'returns a 200' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns a list of jobs' do
          body = JSON.parse(response.body)
          expect(body['data'].length).to eq 0
        end
      end
    end

    describe '#sort[work_plan.priority]' do
      let(:catalogue) { create(:catalogue) }
      let(:product) { create(:product, catalogue: catalogue) }

      let(:project) { make_node('my project', 'S0001', 1, 0, false, true) }
      let(:std_priority_work_plan) { create(:work_plan, product: product, project_id: project.id, priority: "standard") }
      let(:high_priority_work_plan) { create(:work_plan, product: product, project_id: project.id, priority: "high") }

      let(:std_work_order) { create(:work_order, set_uuid: made_up_set.id, work_plan: std_priority_work_plan) }
      let(:high_work_order) { create(:work_order, set_uuid: made_up_set.id, work_plan: high_priority_work_plan) }
      let(:std_work_order2) { create(:work_order, set_uuid: made_up_set.id, work_plan: std_priority_work_plan) }
      let(:high_work_order2) { create(:work_order, set_uuid: made_up_set.id, work_plan: high_priority_work_plan) }

      let(:container) { make_container }
      let(:started_time) { Time.zone.now }

      before do
        create_list(:job, 1, work_order: std_work_order, container_uuid: container.id)
        create_list(:job, 2, work_order: high_work_order, container_uuid: container.id)
        create_list(:job, 3, work_order: std_work_order2, container_uuid: container.id)
        create_list(:job, 4, work_order: high_work_order2, container_uuid: container.id)
        get api_v1_jobs_path, headers: headers, params: { sort: 'work_plan.priority' }
      end

      it 'has an HTTP status of 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the Jobs of a high priority Work Plan first' do
        body = JSON.parse(response.body)
        priorities = body["data"].map { |job| job["attributes"]["priority"] }
        expect(priorities[0..5]).to all eq('high')
        expect(priorities[6..9]).to all eq('standard')
      end
    end
  end
end
