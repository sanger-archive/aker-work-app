# frozen_string_literal: true

require 'rails_helper'
require 'set'

RSpec.describe 'Broker' do
  let(:bunny) { double('Bunny') }

  setup do
    stub_const('Bunny', bunny)
    allow_any_instance_of(Broker).to receive(:add_close_connection_handler).and_return true

    @params = { broker_host: 'broker_host',
                broker_port: 'broker_port',
                broker_username: 'broker_username',
                broker_password: 'broker_password',
                vhost: 'vhost',
                exchange_name: 'exchange_name',
                catalogue_queue: 'catalogue_queue' }

    allow(Rails.application.config).to receive(:events).and_return(@params)
  end

  def mock_connection
    @connection = double('connection')
    @channel = double('channel')
    @exchange = double('exchange')
    @catalogue_queue = double('queue')

    mock_connection_setup
    mock_publishing_setup
    mock_subscribing_setup
  end

  # Mock set-up
  def mock_connection_setup
    allow(bunny).to receive(:new).and_return(@connection)
    allow(@connection).to receive(:start)
    allow(@connection).to receive(:create_channel).and_return(@channel)
    allow(@channel).to receive(:topic).and_return(@exchange)
    allow(@channel).to receive(:queue).and_return(@catalogue_queue)
    allow(@channel).to receive(:confirm_select)
  end

  # Mock publishing
  def mock_publishing_setup
    allow(@exchange).to receive(:publish)
    allow(@channel).to receive(:wait_for_confirms)
  end

  # Mock queue subscription
  def mock_subscribing_setup
    allow(@catalogue_queue).to receive(:subscribe)
  end

  describe '#initialize_connection' do
    it 'initialize methods are called' do
      allow_any_instance_of(Broker)
        .to receive(:start_connection).and_return true
      allow_any_instance_of(Broker)
        .to receive(:exchange_and_queue_handler).and_return true
      allow_any_instance_of(Broker)
        .to receive(:consume_catalogue_queue).and_return true

      broker = Broker.new
      broker.initialize_connection

      expect(broker).to have_received(:start_connection)
      expect(broker).to have_received(:exchange_and_queue_handler)
      expect(broker).to have_received(:consume_catalogue_queue)
      expect(broker).to have_received(:add_close_connection_handler)
    end
  end

  describe '#create_connection' do
    it 'does not create a connection if a connection already exists' do
      mock_connection
      broker = Broker.new

      allow(broker).to receive(:connected?).and_return(true)
      allow(broker).to receive(:start_connection)
      allow(broker).to receive(:exchange_and_queue_handler)
      allow(broker).to receive(:consume_catalogue_queue)
      allow(broker).to receive(:add_close_connection_handler)
      broker.create_connection

      expect(broker).not_to have_received(:start_connection)
      expect(broker).not_to have_received(:exchange_and_queue_handler)
      expect(broker).not_to have_received(:consume_catalogue_queue)
      expect(broker).not_to have_received(:add_close_connection_handler)
    end
  end

  describe '#connected?' do
    it 'should return true when the broker is connected' do
      mock_connection

      broker = Broker.new
      broker.create_connection
      allow(@connection).to receive(:connected?).and_return(true)
      expect(broker.connected?).to eq true
    end

    it 'should send an email when the broker is broken' do
      broker = Broker.new
      allow(broker).to receive(:handle_broker_not_connected)

      expect(broker.connected?).to eq false
      expect(broker).to have_received(:handle_broker_not_connected)
    end
  end

  describe '#start_connection' do
    it 'starts a new connection' do
      mock_connection

      expect(@connection).to receive(:start)
      expect(@connection).to receive(:create_channel)
      expect(@channel).to receive(:topic)
      expect(@channel).to receive(:queue)
      expect(@channel).to receive(:confirm_select)
      expect(@catalogue_queue).to receive(:subscribe)

      broker = Broker.new
      broker.create_connection
    end
  end

  describe '#publish' do
    setup do
      mock_connection
      @event_message = instance_double('EventMessage')
      allow(@event_message).to receive(:generate_json).and_return('message')
    end

    context 'unconfirmed set (of published message indexes) is empty' do
      before(:each) do
        # unconfirmed set of published message indexes
        @unconfirmed_sets = Set.new([])
      end

      it 'publishes a new message to the exchange' do
        allow(@channel).to receive(:unconfirmed_set).and_return(@unconfirmed_sets)

        broker = Broker.new
        expect(@exchange).to receive(:publish).with('message',
                                                    routing_key: EventMessage::ROUTING_KEY)
        broker.publish(@event_message)
      end
    end

    context 'unconfirmed set (of published message indexes) is not empty' do
      before(:each) do
        # unconfirmed set of published message indexes
        @unconfirmed_sets = Set.new([1])
      end

      it 'raises exception if unconfirmed set is not empty' do
        allow(@channel).to receive(:unconfirmed_set).and_return(@unconfirmed_sets)

        broker = Broker.new
        expect(@exchange).to receive(:publish).with('message',
                                                    routing_key: EventMessage::ROUTING_KEY)
        expect(Rails.logger).to receive(:error).with('There is an unconfirmed set in the broker.')

        broker.publish(@event_message)
      end
    end
  end
end
