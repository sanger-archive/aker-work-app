require 'active_support/concern'

module LinkableToContainers
  extend ActiveSupport::Concern

  class_methods do

    def link_to_container(*attrs)
      attrs.each do |attribute|
        stripped_attr = attribute.to_s.sub(/_uuid/, '')

        # Name of the method to be created
        getter_method_name            = stripped_attr.to_sym
        setter_method_name            = "#{stripped_attr}=".to_sym

        # Name of the instance variable we memoize the output of the method
        instance_variable_name = "@#{stripped_attr}"

        # Name of the method to check if attribute is set
        existance_name = "#{attribute}?".to_sym

        # e.g. container_uuid --> container
        define_method getter_method_name do
          return nil unless send(existance_name)
          return instance_variable_get(instance_variable_name) unless instance_variable_get(instance_variable_name).nil?
          return instance_variable_set(instance_variable_name, ExternalRequests::Containers.find_container(send(attribute)))
        end

        # e.g. container_uuid --> container=
        define_method setter_method_name do |container|
          send("#{attribute}=", container&.uuid)
          return instance_variable_set(instance_variable_name, container)
        end

      end
    end

  end

end

module ExternalRequests
  module Containers

    def find_container(container_uuid)
      container_client.find(container_uuid)
    end
    module_function :find_container

    def container_client
      MatconClient::Container
    end
    module_function :container_client

  end
end