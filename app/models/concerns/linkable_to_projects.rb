require 'active_support/concern'

module LinkableToProjects
  extend ActiveSupport::Concern

  class_methods do

    def link_to_project(*attrs)
      attrs.each do |attribute|
        stripped_attr = attribute.to_s.sub(/_id/, '')

        # Name of the method to be created
        getter_method_name = stripped_attr.to_sym
        setter_method_name = "#{stripped_attr}=".to_sym

        # Name of the instance variable we memoize the output of the method
        instance_variable_name = "@#{stripped_attr}"

        # Name of the method to check if attribute is set
        existance_name = "#{attribute}?".to_sym

        define_method getter_method_name do
          return nil unless send(existance_name)
          return instance_variable_get(instance_variable_name) unless instance_variable_get(instance_variable_name).nil?
          return instance_variable_set(instance_variable_name, ExternalRequests::Projects.find_project(send(attribute)))
        end

        define_method setter_method_name do |project|
          send("#{attribute}=", project&.id)
          return instance_variable_set(instance_variable_name, project)
        end

      end
    end

  end
end

module ExternalRequests
  module Projects

    def find_project(project_id)
      study_client.find(project_id).first
    end
    module_function :find_project

    private

    def study_client
      StudyClient::Node
    end
    module_function :study_client

  end
end