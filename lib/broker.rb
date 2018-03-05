# frozen_string_literal: true

require 'bunny'
require 'event_message'
require 'ostruct'

# This class should control connection, publishing and consuming from the broker
class Broker
  attr_accessor :connection
  attr_reader :channel, :exchange, :dlx, :dlx_queue

  def initialize
    @events_config = OpenStruct.new(Rails.configuration.events)
  end

  def create_connection
    !connected? && connect!
  end

  def publish(message)
    create_connection unless connected?
    Rails.logger.debug('Publishing message to broker')
    @exchange.publish(message.generate_json, routing_key: EventMessage::ROUTING_KEY)
    @channel.wait_for_confirms
    raise 'There is an unconfirmed set.' if @channel.unconfirmed_set.count.positive?
  end

  private

  def connect!
    start_connection
    exchange_and_queue_handler
    consume_catalogue_queue
    add_close_connection_handler
  end

  def connected?
    !@connection.nil?
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

    @catalogue_queue = @channel.queue(@events_config.catalogue_queue, passive: true)

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

  def add_close_connection_handler
    at_exit do
      Rails.logger.info('RabbitMQ connection closed.')
      close
    end
  end

  def close
    @connection.close
  end
end
