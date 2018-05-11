# frozen_string_literal: true

require 'broker'

if Rails.configuration.events[:enabled]
  Rails.logger.debug 'Events enabled, trying to initialize...'
  BrokerHandle = Broker.new
  # The connection should be created in the initializer, so we'll keep the following line
  # here (http://rubybunny.info/articles/connecting.html for more info)
  if !BrokerHandle.working?
    Rails.logger.error "Failed to initialise broker"
  end
else
  # Create an "empty" class definition with fake methods to use when events are disabled
  BrokerHandle = Broker.new.tap do |obj|
    obj.instance_eval do
      def publish(obj); end
      def consume; end
      def working?; end
      def connected?; end
    end
  end
end
