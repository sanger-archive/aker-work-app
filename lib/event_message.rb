# frozen_string_literal: true

# Encapsulate a message from the work orders application to be sent to the mesage broker.
class EventMessage
  attr_reader :work_order
  attr_reader :catalogue

  ROUTING_KEY = 'aker.events.work_order'

  # wrapper method to create the JSON message
  def generate_json
    raise 'This must be overridden!'
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
  attr_reader :status

  def initialize(params)
    # For Work Order message
    @work_order = params.fetch(:work_order).decorate
    @status = params.fetch(:status)
    @timestamp = Time.now.utc.iso8601
    @uuid = SecureRandom.uuid
  end

  # Generate the JSON for a Work Order event
  def generate_json
    plan = @work_order.work_plan.decorate
    project = plan.project
    product = plan.product
    process = @work_order.process
    {
      'event_type' => "aker.events.work_order.#{@status}",
      'lims_id' => 'aker',
      'uuid' => @uuid,
      'timestamp' => @timestamp,
      'user_identifier' => plan.owner_email,
      'roles' => [
        {
          'role_type' => 'work_order',
          'subject_type' => 'work_order',
          'subject_friendly_name' => @work_order.name,
          'subject_uuid' => @work_order.work_order_uuid
        },
        {
          'role_type' => 'project',
          'subject_type' => 'project',
          'subject_friendly_name' => project.name,
          'subject_uuid' => project.node_uuid
        },
        {
          'role_type' => 'product',
          'subject_type' => 'product',
          'subject_friendly_name' => product.name,
          'subject_uuid' => product.uuid
        },
        {
          'role_type' => 'process',
          'subject_type' => 'process',
          'subject_friendly_name' => process.name,
          'subject_uuid' => process.uuid
        },
        {
          'role_type' => 'work_plan',
          'subject_type' => 'work_plan',
          'subject_friendly_name' => plan.name,
          'subject_uuid' => plan.uuid
        }
      ],
      'metadata' => metadata,
      'notifier_info' => notifier_info
    }.to_json
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
