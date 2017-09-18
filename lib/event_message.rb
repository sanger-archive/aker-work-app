require 'event_publisher'

class EventMessage
  attr_reader :work_order

  def initialize(params)
    @work_order = params[:work_order]
    @status = params[:status] || @work_order.status
  end

  def trace_id
    ZipkinTracer::TraceContainer.current&.next_id&.trace_id&.to_s
  end

  def generate_json
    proposal = @work_order.proposal
    product = @work_order.product
    {
      "event_type" => "aker.events.work_order.#{@status}",
      "lims_id" => "aker",
      "uuid" => SecureRandom.uuid,
      "timestamp" => Time.now.utc.iso8601,
      "user_identifier" => @work_order.user.email,
      "roles" => [
        {
          "role_type" => "work_order",
          "subject_type" => "work_order",
          "subject_friendly_name" => @work_order.name,
          "subject_uuid" => @work_order.work_order_uuid,
        },
        {
          "role_type" => "proposal",
          "subject_type" => "proposal",
          "subject_friendly_name" => proposal.name,
          "subject_uuid" => proposal.node_uuid,
        },
        {
          "role_type" => "product",
          "subject_type" => "product",
          "subject_friendly_name" => product.name,
          "subject_uuid" => product.product_uuid,
        },
      ],
      "metadata" => {
        "comment" => @work_order.comment,
        "quoted_price" => @work_order.total_cost,
        "desired_completion_date" => @work_order.desired_date,
        "zipkin_trace_id": trace_id,
        "num_materials": @work_order.set.meta["size"],
      },
    }.to_json
  end

end
