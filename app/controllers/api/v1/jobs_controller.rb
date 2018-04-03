module Api
  module V1
    class JobsController < JSONAPI::ResourceController
      before_action :aker_job, only: [:show, :update, :complete, :cancel, :start]

      before_action :check_start, only: [:start]
      before_action :check_cancel, only: [:cancel]
      before_action :check_complete, only: [:complete]

      def complete
        @job.complete!
        jsondata = JSONAPI::ResourceSerializer.new(Api::V1::JobResource).serialize_to_hash(Api::V1::JobResource.new(@job, nil))
        render json: jsondata, status: :ok
      end
      def cancel
        @job.cancel!
        jsondata = JSONAPI::ResourceSerializer.new(Api::V1::JobResource).serialize_to_hash(Api::V1::JobResource.new(@job, nil))
        render json: jsondata, status: :ok        
      end
      def start
        @job.start!
        jsondata = JSONAPI::ResourceSerializer.new(Api::V1::JobResource).serialize_to_hash(Api::V1::JobResource.new(@job, nil))
        render json: jsondata, status: :ok        
      end

      private

      def error_filter
        head :unprocessable_entity
      end

      def check_start
        error_filter unless aker_job.queued?
        true
      end

      def check_complete
        error_filter unless aker_job.active?
        true
      end

      def check_cancel
        error_filter unless aker_job.active?
        true
      end

      def aker_job
        @job ||= Job.find(params[:job_id] || params[:id])
      end

    end
  end
end