require 'completion_cancel_steps/create_containers_step'
require 'completion_cancel_steps/create_new_materials_step'
require 'completion_cancel_steps/update_old_materials_step'
require 'completion_cancel_steps/lock_set_step'
require 'completion_cancel_steps/update_work_order_step'
require 'completion_cancel_steps/fail_step'
require 'completion_cancel_steps/update_job_step'
require 'completion_cancel_steps/create_master_set_step'

module Api
  module V1
    class JobsController < JSONAPI::ResourceController
      before_action :job, only: [:show, :complete, :cancel, :start]
      before_action :check_start, only: [:start]
      before_action :remove_submitter, only: [:complete, :cancel]

      def complete
        finish('complete')
      end

      def cancel
        finish('cancel')
      end

      def start
        job.start!
        jsondata = JSONAPI::ResourceSerializer.new(Api::V1::JobResource).serialize_to_hash(Api::V1::JobResource.new(job, nil))
        render json: jsondata, status: :ok
      end

      def finish(finish_status)
        if BrokerHandle.working? || BrokerHandle.events_disabled?
          RequestStore.store[:x_authorisation] = { email: job.work_order.owner_email, groups: ['world'] }
          validator = JobValidatorService.new(job, params_for_completion)
          valid = validator.validate?
          if valid
            result = complete_job(finish_status)
            # if params_for_completion[:work_order][:updated_materials].length >= 1
            #   work_order.update(material_updated: true)
            # end
            render json: { meta: { message: result[:msg] } }, status: result[:status]
          else
            result = validator.errors
            render json: { errors: [ detail: result[:msg] ] }, status: result[:status]
          end
        else
          render json: { errors: [ detail: "RabbitMQ broker is broken" ] }, status: 500
        end
      end

      private

      def error_started
        render json: {"msg": "This job has already been started."}, status: :unprocessable_entity
      end

      def check_start
        error_started unless job.queued?
        true
      end

      def params_for_completion
        p = { job: params.require(:job).as_json.deep_symbolize_keys }

        if p[:job][:updated_materials].nil?
          p[:job][:updated_materials] = []
        end

        if p[:job][:new_materials].nil?
          p[:job][:new_materials] = []
        end

        if p[:job][:containers].nil?
          p[:job][:containers] = []
        end

        return p
      end

      def complete_job(finish_status)
        success = false
        cleanup = false
        params = params_for_completion
        begin
          new_material_step = CreateNewMaterialsStep.new(job, params)
          updated_material_step = UpdateOldMaterialsStep.new(job, params)

          success = DispatchService.new.process([
            CreateContainersStep.new(job, params),
            new_material_step,
            updated_material_step,
            UpdateJobStep.new(job, params, finish_status),
            UpdateWorkOrderStep.new(job),
            LockSetStep.new(job.decorate, params, new_material_step, updated_material_step),
            CreateMasterSetStep.new(job)
          ])

          cleanup = !success
        rescue => e
          puts "*"*70
          puts "Error from dispatch service:"
          puts e
          puts e.backtrace
        ensure
          if !success && !cleanup
            job.broken!
          end
        end

        if success
          msg = flash[:notice] = "Your job is #{text_for_finish_status(finish_status)}"
          if job.work_order.concluded?
            generate_concluded_event
          end
        elsif cleanup
          msg = flash[:error] = "The job could not be #{text_for_finish_status(finish_status)}"
        else
          msg = flash[:error] = "There has been a problem with the job update. Please contact support."
        end

        return {msg: msg, status: success ? 200 : 502 }
      end

    private

      def job
        @job ||= Job.find(params[:job_id] || params[:id])
      end

      def text_for_finish_status(finish_status)
        if (finish_status == 'complete')
          return 'completed'
        elsif (finish_status== 'cancel')
          return 'cancelled'
        else
          return finish_status
        end
      end

      def generate_concluded_event
        job.work_order.generate_concluded_event
      end

      # Ignore the submitter_id in material metadata
      # TODO: Move this to CreateNewMaterialsStep and UpdateOldMaterialsStep
      def remove_submitter
        updated_materials = params.fetch(:job).dig("updated_materials")
        new_materials = params.fetch(:job).dig("new_materials")
        params["job"]["updated_materials"].each { |m| m.delete(:submitter_id) } if updated_materials
        params["job"]["new_materials"].each { |m| m.delete(:submitter_id) } if new_materials
      end
    end
  end
end