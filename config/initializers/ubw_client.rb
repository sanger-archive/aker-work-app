require 'ubw_client'
require 'set'

Rails.application.config.after_initialize do
  Ubw::Client.site = Rails.application.config.ubw_service_url

  Ubw::Client.connection do |connection|
    connection.proxy {}
  end

  if !Rails.application.config.ubw[:enabled]

    module UbwClient

      def self.get_unit_prices(module_names, cost_code)
        module_names.inject({}) do |memo, module_name|
          memo[module_name] = BigDecimal.new("#{Random.rand(100)}.#{Random.rand(99)}")
          memo
        end
      end

      def self.missing_unit_prices(module_names, cost_code)
        if module_names.is_a? String
          module_name_set = Set[module_names]
        else
          module_name_set = Set.new(module_names)
        end
        module_name_set - get_unit_prices(module_names, cost_code).keys
      end


      # Looks up the modules by name without a cost code.
      # Module names are valid if they have a listed price (for any cost code).
      # Returns the subset of the matching module names that are valid.
      def self.valid_module_names(module_names)
        if module_names.is_a? String
          Set[module_names]
        else
          Set.new(module_names)
        end
      end

      # Looks up the modules by name without a cost code.
      # Module names are invalid if they have no listed price for any cost code.
      # Returns the subset of the given module names that are invalid.
      def self.invalid_module_names(module_names)
        if module_names.is_a? String
          module_name_set = Set[module_names]
        else
          module_name_set = Set.new(module_names)
        end
        module_name_set - valid_module_names(module_names)
      end

    end

  end
end
