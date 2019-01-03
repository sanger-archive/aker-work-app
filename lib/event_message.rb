# frozen_string_literal: true

# Encapsulate a message from the work orders application to be sent to the mesage broker.
class EventMessage

  ROUTING_KEY = 'aker.events.work_order'

  # wrapper method to create the JSON message
  def generate_json
    raise 'This must be overridden!'
  end

private

  def role(obj, role_type, params={})
    {
      'role_type' => role_type,
      'subject_type' => params[:subject_type] || role_type,
      'subject_friendly_name' => params[:name] || obj.name,
      'subject_uuid' => params[:uuid] || obj.uuid
    }
  end

  def project_role(project)
    role(project, 'project', uuid: project.node_uuid)
  end

  def product_role(product)
    role(product, 'product')
  end

  def work_order_role(order)
    role(order, 'work_order', uuid: order.work_order_uuid)
  end

  def process_role(process)
    role(process, 'process')
  end

  def work_plan_role(plan)
    role(plan, 'work_plan')
  end

end

# A message specific to a catalogue that has been received
class CatalogueEventMessage < EventMessage
  def initialize(params)
    # For Catalogue message
    @catalogue = params.fetch(:catalogue)
    @catalogue_error = params.fetch(:error)
    @uuid = SecureRandom.uuid
    @timestamp = Time.now.utc.iso8601
  end

  # wrapper method to create the JSON message
  def generate_json
    if @catalogue_error
      generate_rejected_catalogue_json
    else
      generate_accepted_catalogue_json
    end
  end

private

  # Generate the JSON for a catalogue accepted event
  def generate_accepted_catalogue_json
    {
      'event_type' => 'aker.events.catalogue.accepted',
      'timestamp' => @timestamp,
      'uuid' => @uuid,
      'roles' => [],
      'user_identifier' => @catalogue[:lims_id],
      'lims_id' => @catalogue[:lims_id],
      'metadata' => {
        'pipeline' => @catalogue[:pipeline]
      }
    }.to_json
  end

  # Generate the JSON for a catalogue rejected event
  def generate_rejected_catalogue_json
    {
      'event_type' => 'aker.events.catalogue.rejected',
      'timestamp' => @timestamp,
      'uuid' => @uuid,
      'roles' => [],
      'user_identifier' => @catalogue[:lims_id],
      'lims_id' => @catalogue[:lims_id],
      'metadata' => {
        'error' => @catalogue_error
      }
    }.to_json
  end
end

# A message specific to a work order
class WorkOrderEventMessage < EventMessage
  attr_reader :work_order
  attr_reader :status

  def initialize(params)
    # For Work Order message
    @work_order = params.fetch(:work_order).decorate
    @status = params.fetch(:status)
    @dispatched_jobs = params[:dispatched_jobs] || []
    @forwarded_jobs = params[:forwarded_jobs] || []
    @timestamp = Time.now.utc.iso8601
    @uuid = SecureRandom.uuid
  end

  # Generate the JSON for a Work Order event
  def generate_json
    plan = @work_order.work_plan.decorate
    {
      'event_type' => "aker.events.work_order.#{@status}",
      'lims_id' => 'aker',
      'uuid' => @uuid,
      'timestamp' => @timestamp,
      'user_identifier' => plan.owner_email,
      'roles' => roles,
      'metadata' => metadata,
      'notifier_info' => notifier_info,
    }.to_json
  end

private

  def roles
    plan = @work_order.work_plan.decorate
    project = plan.project
    product = plan.product
    process = @work_order.process
    
    [
        work_order_role(@work_order),
        project_role(project),
        product_role(product),
        process_role(process),
        work_plan_role(plan),
    ] +
    job_roles(@dispatched_jobs, 'dispatched_job') +
    job_roles(@forwarded_jobs, 'forwarded_job')
  end

  def job_roles(jobs, roletype)
    jobs.map { |job| role(job, roletype, subject_type: 'job') }
  end

  def metadata
    if @status == 'dispatched'
      metadata_for_dispatched
    else
      metadata_for_concluded
    end
  end

  def metadata_for_dispatched
    plan = @work_order.work_plan
    {
      'work_order_id' => @work_order.id,
      'quoted_price' => @work_order.total_cost,
      'num_materials' => num_materials,
      'data_release_strategy_uuid' => plan.data_release_strategy_id
    }
  end

  def num_materials
    @work_order.set_size || 0
  end

  def metadata_for_concluded
    {
      'work_order_id' => @work_order.id,
      'num_completed_jobs' => num_completed_jobs,
      'num_cancelled_jobs' => num_cancelled_jobs
    }
  end

  def num_completed_jobs
    @work_order.jobs.object.completed.length
  end

  def num_cancelled_jobs
    @work_order.jobs.object.cancelled.length
  end

  # Information only required by the notifier can be added here which should be ignored by the
  # events consumer and avoid being saved to the events warehouse
  def notifier_info
    plan = @work_order.work_plan
    if @status == 'queued'
      {
        'work_plan_id' => plan.id
      }
    else
      {
        'work_plan_id' => plan.id,
        'drs_study_code' => plan.data_release_strategy&.study_code
      }
    end
  end
end

class JobEventMessage < EventMessage

  def initialize(params)
    @job = params.fetch(:job)
    @status = params.fetch(:status)
    @timestamp = Time.now.utc.iso8601
    @uuid = SecureRandom.uuid
  end

  def generate_json
    {
      'event_type' => "aker.events.job.#{@status}",
      'lims_id' => 'aker',
      'uuid' => @uuid,
      'timestamp' => @timestamp,
      'user_identifier' => @job.work_order.work_plan.owner_email,
      'roles' => roles,
      'metadata' => metadata,
    }.to_json
  end

private

  def roles
    order = @job.work_order
    plan = order.work_plan.decorate

    [
      work_order_role(order),
      project_role(plan.project),
      product_role(plan.product),
      process_role(order.process),
      work_plan_role(plan),
      role(@job, 'job'),
    ]
  end

  def metadata
    {
      'work_order_id' => @job.work_order_id,
      'work_plan_id' => @job.work_order.work_plan_id,
    }
  end
end
