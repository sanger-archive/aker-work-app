# The EventConsumer currently only listens on the aker.events.catalogue queue
class EventConsumer

  def initialize(config = {})
    @broker_host = config[:broker_host]
    @broker_port = config[:broker_port]
    @broker_vhost = config[:broker_vhost]
    @broker_username = config[:broker_username]
    @broker_password = config[:broker_password]
    @exchange_name = config[:exchange_name]
    @catalogue_queue_name = config[:catalogue_queue_name]
  end

  def create_connection
    !connected? && connect!
  end

  def connect!
    start_connection
    start_listening
    add_close_connection_handler
  end

  def connected?
    !@connection.nil?
  end

  private

  def start_connection
    @connection = Bunny.new(
      host: @broker_host,
      port: @broker_port,
      vhost: @broker_vhost,
      user: @broker_username,
      pass: @broker_password,
      threaded: true
    )
    @connection.start
  end

  def start_listening
    @channel = @connection.create_channel
    dl_exchange_name = @exchange_name + '.deadletters'
    @dlx = @channel.fanout(dl_exchange_name, durable: true)
    @queue = @channel.queue(@catalogue_queue_name,
                   auto_delete: false,
                   durable: true,
                   arguments: {
                     "x-dead-letter-exchange": @dlx.name
                   }).bind(@exchange_name, routing_key: 'aker.events.catalogue.new')

    @queue.subscribe(manual_ack: true) do |delivery_info, metadata, body|
      data = nil
      begin
        data = JSON.parse(body, symbolize_names: true)[:catalogue]
        puts data
        Catalogue.create_with_products(data)
        @channel.ack(delivery_info.delivery_tag)
      rescue StandardError => e
        puts e
        puts e.backtrace
        @channel.reject(delivery_info.delivery_tag)
        handle_catalogue_failure(data)
      end
    end
  end

  def handle_catalogue_failure(data)
    if data && data[:lims_id]
      # Something went wrong! Cancel the current catalogue for the offending LIMS
      puts "Cancelling catalogue"
      Catalogue.where(lims_id: data[:lims_id]).update_all(current: false)
    end
  end

  def add_close_connection_handler
    at_exit do
      @channel.close
      @connection.close
    end
  end

end
