# frozen_string_literal: true

require 'event_publisher'

# Encapsulate a message from the work orders application to be sent to the mesage broker.
class EventMessage
  attr_reader :work_order

  def initialize(params)
    @work_order = params.fetch(:work_order)
    @status = params.fetch(:status)
  end

  def trace_id
    ZipkinTracer::TraceContainer.current&.next_id&.trace_id&.to_s
  end

  def metadata
    if @status == 'submitted'
      metadata_for_submitted
    else
      metadata_for_completed
    end
  end

  def metadata_for_submitted
    {
      'work_order_id' => @work_order.id,
      'comment' => @work_order.comment,
      'quoted_price' => @work_order.total_cost,
      'desired_completion_date' => @work_order.desired_date,
      'zipkin_trace_id' => trace_id,
      'num_materials' => num_materials
    }
  end

  def num_materials
    if (@work_order.set&.meta && @work_order.set.meta['size'])
      @work_order.set.meta['size']
    else
      0
    end
  end

  def metadata_for_completed
    {
      'work_order_id' => @work_order.id,
      'comment' => @work_order.close_comment,
      'zipkin_trace_id' => trace_id,
      'num_new_materials' => num_new_materials
    }
  end

  def num_new_materials
    if (@work_order.finished_set&.meta && @work_order.finished_set.meta['size'])
      @work_order.finished_set.meta['size']
    else
      0
    end
  end

  def generate_json
    project = @work_order.proposal
    product = @work_order.product
    {
      'event_type' => "aker.events.work_order.#{@status}",
      'lims_id' => 'aker',
      'uuid' => SecureRandom.uuid,
      'timestamp' => Time.now.utc.iso8601,
      'user_identifier' => @work_order.owner_email,
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
          'subject_uuid' => product.product_uuid
        }
      ],
      'metadata' => metadata
    }.to_json
  end
end
