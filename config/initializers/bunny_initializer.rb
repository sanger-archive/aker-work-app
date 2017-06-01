require 'bunny'
require 'event_publisher'
require 'ostruct'

if Rails.configuration.enable_events_sending
  EventService = EventPublisher.new(event_conn: Rails.configuration.events_queue_connection, queue_name: Rails.configuration.events_queue_name)
else
  EventService = Class.new do 
    def self.publish(obj)
    end
  end
end
