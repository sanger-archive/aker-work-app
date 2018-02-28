# The EventConsumer currently only listens on the aker.events.catalogue queue
class EventConsumer

  def initialize(config = {})
    debugger
    @broker_host = config.fetch(:broker_host)
    @broker_port = config.fetch(:broker_port)
    @broker_vhost = config.fetch(:broker_vhost)
    @broker_username = config.fetch(:broker_username)
    @broker_password = config.fetch(:broker_password)
    @exchange_name = config.fetch(:exchange_name)
    @catalogue_queue_name = config.fetch(:catalogue_queue_name)
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
    @queue = @channel.queue(
      @catalogue_queue_name,
      auto_delete: false,
      durable: true,
      arguments: {
        "x-dead-letter-exchange": @dlx.name
      }
    ).bind(@exchange_name, routing_key: 'aker.events.catalogue.new')

    @queue.subscribe(manual_ack: true) do |delivery_info, metadata, body|
      data = nil
      begin
        data = JSON.parse(body, symbolize_names: true)[:catalogue]
        Catalogue.create_with_products(data)
        @channel.ack(delivery_info.delivery_tag)
      rescue JSON::ParserError => e
        # JSON Parsing failed. This error is caught separately as the standard
        # message tends to include a chunk (if not all) of the malformed
        # catalog, so we supply our own shorter error for the event
        Rails.logger.error("Catalogue malformed with exception: #{e}")
        Rails.logger.error(e.backtrace.join("\n"))
        Rails.logger.error("Malformed message: \n #{body}")
        publish_event(data, 'JSON Parser raised an error')
      rescue StandardError => e
        # Something has gone wrong in the processing of the catalog
        Rails.logger.error("Catalog processing failed with exception: #{e}")
        Rails.logger.error(e.backtrace.join("\n"))
        Rails.logger.error("Catalogue Invalid. JSON received: \n #{data}")
        @channel.reject(delivery_info.delivery_tag)
        handle_catalogue_failure(data)
        publish_event(data, e.message)
      else
        # Everything seems to have worked, so publish publish a catalog accepted
        # event
        publish_event(data)
      end
    end
  end

  def publish_event(catalogue_params, error_msg = nil)
    message = EventMessage.new(catalogue: catalogue_params, error: error_msg)
    EventService.publish(message)
  end

  def handle_catalogue_failure(data)
    if data && data[:lims_id]
      # Something went wrong! Cancel the current catalogue for the offending LIMS
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
