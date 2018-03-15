# frozen_string_literal: true

require 'broker'

if Rails.configuration.events[:enabled]
  Rails.logger.debug 'Events enabled, trying to initialize...'
  BrokerHandle = Broker.new
  # The connection should be created in the initializer, so we'll keep the following line
  # here (http://rubybunny.info/articles/connecting.html for more info)
  BrokerHandle.create_connection
else
  # Create an "empty" class definition with fake methods to use when events are disabled
  BrokerHandle = Class.new do
    def self.publish(obj); end

    def self.consume(); end

    def self.create_connection; end
  end
end
