require 'event_message'

class EventPublisher

  attr_accessor :connection

  def initialize(config)
    @event_conn = config[:event_conn]
    @queue_name = config[:queue_name]
    set_config
    add_close_connection_handler
  end

  def send(message)
    @exchange.publish(message.generate_json, routing_key: @queue.name)
  end

  def set_config
    @connection = Bunny.new(@event_conn)
    @connection.start

    ch = @connection.create_channel
    @queue = ch.queue(@queue_name, :auto_delete => true)

    @exchange = ch.default_exchange
  end

  def close
    @connection.close
  end  

  private

  def add_close_connection_handler 
    at_exit { 
      puts 'RabbitMQ connection close'
      close 
      exit 0
    }
  end

end