require 'event_publisher'

class EventMessage

  attr_reader :work_order

  def initialize(params)
    @work_order = params[:work_order]
    @status = params[:status] || @work_order.status
  end

  def generate_json
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
             "subject_uuid" => @work_order.work_order_uuid
          }
       ],
       "metadata" => {
          "comment" => @work_order.comment,
          "quoted_price" => @work_order.total_cost,
          "desired_completion_date" => @work_order.desired_date,
          "zipkin_trace_id":"a_uuid_...",
          "num_materials": @work_order.set.meta["size"]
       }
    }.to_json
  end

end
