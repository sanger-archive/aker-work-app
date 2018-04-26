# frozen_string_literal: true

require 'rails_helper'
require 'set'

RSpec.describe 'Broker' do
  let(:bunny) { double('Bunny') }

  let(:params) do
    {
      enabled: true,
      broker_host: 'broker_host',
      broker_port: 'broker_port',
      broker_username: 'broker_username',
      broker_password: 'broker_password',
      vhost: 'vhost',
      exchange_name: 'exchange_name',
      catalogue_queue: 'catalogue_queue',
    }
  end

  let(:connection) { double('connection') }
  let(:channel) { double('channel') }
  let(:exchange) { double('exchange') }
  let(:catalogue_queue) { double('queue') }
  let(:email) { double('email', deliver_later: nil) }

  let(:broker) { Broker.new }

  setup do
    stub_const('Bunny', bunny)
    allow_any_instance_of(Broker).to receive(:add_close_connection_handler).and_return true
    allow(Rails.application.config).to receive(:events).and_return(params)
  end

  def mock_connection
    mock_connection_setup
    mock_publishing_setup
    mock_subscribing_setup
  end

  # Mock set-up
  def mock_connection_setup
    allow(bunny).to receive(:new).and_return(connection)
    allow(connection).to receive(:start)
    allow(connection).to receive(:create_channel).and_return(channel)
    allow(channel).to receive(:topic).and_return(exchange)
    allow(channel).to receive(:queue).and_return(catalogue_queue)
    allow(channel).to receive(:confirm_select)
    allow(channel).to receive(:unconfirmed_set).and_return(nil)
  end

  # Mock publishing
  def mock_publishing_setup
    allow(exchange).to receive(:publish)
    allow(channel).to receive(:wait_for_confirms)
  end

  # Mock queue subscription
  def mock_subscribing_setup
    allow(catalogue_queue).to receive(:subscribe)
  end

  describe '#working?' do
    it 'should call setup methods with not connected' do
      @connected = false

      expect(broker).to receive(:start_connection) { @connected = true }
      expect(broker).to receive(:exchange_and_queue_handler)
      expect(broker).to receive(:consume_catalogue_queue)
      expect(broker).to receive(:add_close_connection_handler)
      allow(broker).to receive(:connected?) { @connected }

      expect(broker.working?).to be_truthy
    end

    it 'should return true not create a connection if a connection already exists' do
      allow(broker).to receive(:connected?).and_return(true)
      allow(broker).to receive(:unconfirmed?).and_return(false)
      allow(broker).to receive(:start_connection)
      allow(broker).to receive(:exchange_and_queue_handler)
      allow(broker).to receive(:consume_catalogue_queue)
      allow(broker).to receive(:add_close_connection_handler)

      expect(broker.working?).to be_truthy

      expect(broker).not_to have_received(:start_connection)
      expect(broker).not_to have_received(:exchange_and_queue_handler)
      expect(broker).not_to have_received(:consume_catalogue_queue)
      expect(broker).not_to have_received(:add_close_connection_handler)
    end

    it 'should return false and send an email if it fails to connect' do
      allow(broker).to receive(:connected?).and_return(false)
      expect(broker).to receive(:start_connection).and_raise("Something went wrong")
      expect(WorkOrderMailer).to receive(:broker_not_connected).and_return(email)
      expect(email).to receive(:deliver_later)

      expect(broker.working?).to be_falsey
    end

    it 'should return false and send an email if there are unconfirmed things' do
      mock_connection
      broker.create_connection
      allow(connection).to receive(:connected?).and_return(true)
      allow(channel).to receive(:unconfirmed_set).and_return(Set.new([1]))

      expect(WorkOrderMailer).to receive(:broker_unconfirmed).and_return(email)
      expect(email).to receive(:deliver_later)

      expect(broker.working?).to be_falsey
    end

  end

  describe '#connected?' do
    it 'should return true when the broker is connected' do
      mock_connection

      broker.create_connection
      allow(connection).to receive(:connected?).and_return(true)
      expect(broker.connected?).to be_truthy
    end

    it 'should return false when the broken is not connected' do
      expect(broker.connected?).to be_falsey
    end
  end

  describe '#start_connection' do
    it 'starts a new connection' do
      mock_connection

      expect(connection).to receive(:start)
      expect(connection).to receive(:create_channel)
      expect(channel).to receive(:topic)
      expect(channel).to receive(:queue)
      expect(channel).to receive(:confirm_select)
      expect(catalogue_queue).to receive(:subscribe)

      broker.create_connection
    end
  end

  describe '#publish' do
    let(:event_message) { instance_double('EventMessage', generate_json: 'message') }
    setup do
      mock_connection
    end

    context 'unconfirmed set (of published message indexes) is empty' do

      it 'should publish the message' do
        allow(channel).to receive(:unconfirmed_set).and_return(Set.new([]))

        expect(exchange).to receive(:publish).with('message',
                                                    routing_key: EventMessage::ROUTING_KEY)
        broker.publish(event_message)
      end
    end

    context 'unconfirmed set (of published message indexes) is not empty' do

      it 'should raise an exception' do
        allow(channel).to receive(:unconfirmed_set).and_return(Set.new([1]))

        expect(exchange).to receive(:publish).with('message',
                                                    routing_key: EventMessage::ROUTING_KEY)
        expect(Rails.logger).to receive(:error).with('There is an unconfirmed set in the broker.')
        expect { broker.publish(event_message) }.to raise_error "The event message was not confirmed."
      end
    end
  end
end
