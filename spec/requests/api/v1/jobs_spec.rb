require 'rails_helper'

RSpec.describe 'Api::V1::Jobs', type: :request do
  let(:headers) do
    {
      "Content-Type" => "application/vnd.api+json",
      "Accept" => "application/vnd.api+json"
    }
  end

  describe 'Resource' do
    context 'GET' do
      let(:order) { create :work_order }
      let(:job) { create :job, work_order: order}
      before do
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
        expect(obtained_job['data']['attributes']['work-order-id']).to eq(job.work_order_id)
      end
    end

    context 'PUT' do
      let(:order) { create :work_order }
      let(:job) { create :job, work_order: order}

      describe '#start' do
        context 'when job is queued' do
          before do
            put api_v1_job_start_path(job), headers: headers
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
            put api_v1_job_start_path(job), headers: headers
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
        context 'when job is active' do
          before do
            job.start!
            put api_v1_job_complete_path(job), headers: headers
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
        end
        context 'when job is queued' do
          before do
            put api_v1_job_complete_path(job), headers: headers
          end

          it 'returns a failure' do
            expect(response).to have_http_status(:unprocessable_entity)
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
            put api_v1_job_complete_path(job), headers: headers
          end

          it 'returns a failure' do
            expect(response).to have_http_status(:unprocessable_entity)
          end

          it 'does not change the status' do
            job.reload
            expect(job.status).to eq('completed')
          end
        end

      end

      describe '#cancel' do
        context 'when job is active' do
          before do
            job.start!
            put api_v1_job_cancel_path(job), headers: headers
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
            put api_v1_job_cancel_path(job), headers: headers
          end

          it 'returns a failure' do
            expect(response).to have_http_status(:unprocessable_entity)
          end

          it 'does not change the status' do
            job.reload
            expect(job.status).to eq('queued')
          end
        end
        context 'when job is cancelled' do
          before do
            job.start!
            job.cancel!
            put api_v1_job_cancel_path(job), headers: headers
          end

          it 'returns a failure' do
            expect(response).to have_http_status(:unprocessable_entity)
          end

          it 'does not change the status' do
            job.reload
            expect(job.status).to eq('cancelled')
          end
        end

      end

    end
  end
end