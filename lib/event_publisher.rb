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
      connect!
    end
  end

  def connect!
    set_config
    add_close_connection_handler
  end

  def connected?
    !@connection.nil?
  end

  def publish(message)
    create_connection if !connected?
    @exchange.publish(message.generate_json, routing_key: @queue.name)
    @channel.wait_for_confirms
    if @channel.unconfirmed_set.count > 0
      raise "There is an unconfirmed set"
    end
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
    # threaded is set to false because otherwise the connection creation is not working
    @connection = Bunny.new(@event_conn, threaded: false)
    @connection.start

    @channel = @connection.create_channel

    # auto_delete false ensures that we dont destroy the queue when there are no messages and no 
    # consumers are running
    @queue = channel.queue(@queue_name, :auto_delete => false)

    @exchange = @channel.default_exchange

    @channel.confirm_select
  end


end

