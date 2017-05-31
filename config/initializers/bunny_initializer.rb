require 'bunny'
require 'event_publisher'

if Rails.configuration.enable_events_sending
  EventService = EventPublisher.new(event_conn: Rails.configuration.events_queue_connection, queue_name: Rails.configuration.events_queue_name)
end
