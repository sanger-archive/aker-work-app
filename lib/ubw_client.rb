require 'set'
require 'bigdecimal'

module UbwClient

  # Looks up modules by name and gets their unit price with the given cost code.
  # Returns a hash of module name to unit price (as a BigDecimal).
  def self.get_unit_prices(module_names, cost_code)
    Ubw::Price.where(module_name: module_names, cost_code: cost_code).inject({}) do |memo, price|
      if price.unit_price
        memo[price.module_name] = BigDecimal.new(price.unit_price)
      end
      memo
    end
  end

  # Looks up the prices of modules by name with the given cost code.
  # Returns the set of given module names that do not have a unit price for the given cost code.
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
    Ubw::Price.where(module_name: module_names).map(&:module_name).to_set
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
