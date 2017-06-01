require 'event_publisher'

class EventMessage

  attr_reader :work_order

  def initialize(params)
    @work_order = params[:work_order]
  end

  def generate_json
    @work_order.to_json
  end

end