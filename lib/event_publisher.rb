require 'event_message'

class EventPublisher

  attr_accessor :connection
  attr_reader :channel, :exchange

  def initialize(config={})
    @event_conn = config[:event_conn]
    @queue_name = config[:queue_name]
  end

  def create_connection
    if !connected?
      set_config
      add_close_connection_handler
    end
  end

  def connected?
    !@connection.nil?
  end

  def publish(message)
    create_connection if !connected?
    @exchange.publish(message.generate_json, routing_key: @queue.name)
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

  def set_config
    @connection = Bunny.new(@event_conn)
    @connection.start

    @channel = @connection.create_channel

    @queue = channel.queue(@queue_name, :auto_delete => true)

    #@channel.confirm_select
    @exchange = @channel.default_exchange
  end


end

