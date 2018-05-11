# frozen_string_literal: true

require 'bunny'
require 'event_message'
require 'ostruct'
require 'work_order_mailer'

# This class should control connection, publishing and consuming from the broker
class Broker
  attr_accessor :connection
  attr_reader :channel, :exchange, :dlx, :dlx_queue

  def initialize
    @events_config = OpenStruct.new(Rails.configuration.events)
  end

  def create_connection
    connected? || connect
  end

  def connected?
    @connection&.connected?
  end

  def working?
    if connected?
      return true unless unconfirmed?
      handle_broker_unconfirmed
      return false
    else
      return connect
    end
  end

  def publish(message)
    return if events_disabled?
    # self.working? should have been checked before this method was called.
    # If it is not working now, raise an exception.
    if !working?
      Rails.logger.error("Publishing aborted: #{message}")
      raise "The message could not be published"
    end
    Rails.logger.debug('Publishing message to broker')
    @exchange.publish(message.generate_json, routing_key: EventMessage::ROUTING_KEY)
    @channel.wait_for_confirms
    if unconfirmed?
      Rails.logger.error('There is an unconfirmed set in the broker.')
      raise "The event message was not confirmed."
    end
  end

  def events_enabled?
    @events_config.enabled
  end

  def events_disabled?
    !events_enabled?
  end

private

  def unconfirmed?
    @channel.unconfirmed_set.present? # unconfirmed_set may return nil or a set that may be empty
  end

  def connect!
    start_connection
    exchange_and_queue_handler
    consume_catalogue_queue
    add_close_connection_handler
    handle_broker_connected
    return true
  end

  # This returns true if successful, false if unsuccessful.
  # It logs errors and sends emails as appropriate.
  def connect
    begin
      return connect!
    rescue => e
      Rails.logger.error "Failed to connect to RabbitMQ"
      Rails.logger.error e
      handle_broker_not_connected
      return false
    end
  end

  def start_connection
    Rails.logger.info('Connecting to RabbitMQ...')
    @connection = Bunny.new host: @events_config.broker_host,
                            port: @events_config.broker_port,
                            username: @events_config.broker_username,
                            password: @events_config.broker_password,
                            vhost: @events_config.vhost
    @connection.start
    Rails.logger.info('Connection to RabbitMQ established')
  end

  def exchange_and_queue_handler
    @channel = @connection.create_channel

    # Get a handle to the topic exchange which will send messages to queues bound to the exchange
    #   using specific routing keys
    @exchange = @channel.topic(@events_config.exchange, passive: true)

    @catalogue_queue = @channel.queue(@events_config.catalogues_queue, passive: true)

    # To be able to wait_for_confirms in publish()
    @channel.confirm_select
  end

  def consume_catalogue_queue
    @catalogue_queue.subscribe(
      manual_ack: true,
      consumer_tag: 'work_orders_consumer'
    ) do |delivery_info, _properties, body|
      Rails.logger.debug('Message received on catalogue queue')
      data = nil
      begin
        data = JSON.parse(body, symbolize_names: true)[:catalogue]
        Catalogue.create_with_products(data)
        # Acknowledge that the message was received and parsed correctly
        @channel.ack(delivery_info.delivery_tag, false)
      rescue JSON::ParserError => e
        # JSON Parsing failed. This error is caught separately as the standard message tends to
        # include a chunk (if not all) of the malformed catalogue, so we supply our own shorter
        # error for the event
        handle_parser_error(e, data)
      rescue StandardError => e
        # Something has gone wrong in the processing of the catalogue
        handle_standard_error(e, data, delivery_info)
      else
        # Everything seems to have worked, so publish a 'catalogue accepted' event
        publish(CatalogueEventMessage.new(catalogue: data, error: nil))
      end
    end
  end

  def handle_parser_error(e, data)
    Rails.logger.error("Catalogue malformed with exception: #{e}")
    Rails.logger.error(e.backtrace.join("\n"))
    Rails.logger.error("Malformed message: \n #{body}")
    message = CatalogueEventMessage.new(catalogue: data,
                                        error: 'JSON Parser raised an error')

    # Send a message that the catalogue has failed
    publish(message)
  end

  def handle_standard_error(e, data, delivery_info)
    Rails.logger.error("Catalogue processing failed with exception: #{e}")
    Rails.logger.error(e.backtrace.join("\n"))
    Rails.logger.error("Catalogue invalid. JSON received: \n #{data}")
    @channel.reject(delivery_info.delivery_tag)
    handle_catalogue_failure(data)

    # Send a message that the catalogue has failed
    publish(CatalogueEventMessage.new(catalogue: data, error: e))
  end

  def handle_catalogue_failure(data)
    return unless data && data[:lims_id]
    # Something went wrong! Cancel the current catalogue for the offending LIMS
    Catalogue.where(lims_id: data[:lims_id]).update_all(current: false)
  end

  def handle_broker_not_connected
    unless @emailed_about_outage
      WorkOrderMailer.broker_not_connected.deliver_later
      @emailed_about_outage = true
    end
  end

  def handle_broker_connected
    if @emailed_about_outage
      WorkOrderMailer.broker_reconnected.deliver_later
      @emailed_about_outage = false
    end
  end

  def handle_broker_unconfirmed
    unless @emailed_about_outage
      WorkOrderMailer.broker_unconfirmed.deliver_later
      @emailed_about_outage = true
    end
  end

  def add_close_connection_handler
    unless @close_handler_added
      at_exit do
        Rails.logger.info('RabbitMQ connection closed.')
        close
      end
      @close_handler_added = true
    end
  end

  def close
    @connection&.close
  end
end
