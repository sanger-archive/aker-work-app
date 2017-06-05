require 'event_publisher'

class EventMessage

  attr_reader :work_order

  def initialize(params)
    @work_order = params[:work_order]
    @status = params[:status] || @work_order.status
  end

  def generate_json
    {
       "event_type":"aker.events.work_order.#{@status}",
       "lims_id":"aker",
       "uuid":SecureRandom.uuid,
       "timestamp":(Time.now.to_f*1000).to_i,
       "user_identifier":@work_order.user.email,
       "roles":[
          {
             "role_type":"work_order",
             "subject_type":"work_order",
             "subject_friendly_name":@work_order.name,
             "subject_uuid":@work_order.work_order_uuid
          }
       ],
       "metadata":{
          "comment":@work_order.comment
       }
    }.to_json
  end

end