module Api
  module V1
    class JobsController < JSONAPI::ResourceController
      before_action :aker_job

      def complete
        @job.complete!
      end
      def cancel
        @job.cancel!
      end
      def start
        @job.start!
      end

      private

      def aker_job
        @job ||= Job.find(params[:job_id] || params[:id])
      end
    end
  end
end