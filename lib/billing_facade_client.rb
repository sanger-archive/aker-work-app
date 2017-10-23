require 'faraday'
require 'bigdecimal'

module BillingFacadeClient

  def self.send_event(work_order, name)
    connection.post("/events", {eventName: name, workOrderId: work_order.id}.to_json)
    return true if r.status==200
    return false
  end

  def self.validate_single_value(path)
    r = connection.get(path)
    return false unless r.status == 200
    response = JSON.parse(r.body).symbolize_keys
    return response[:verified]
  end

  def self.validate_multiple_values(path, params)
    r = connection.post(path, params.to_json )
    return [] if r.status==200
    response = JSON.parse(r.body)
    invalid_cost_codes = response.keys.select{|cost_code| !response[cost_code] }
    return invalid_cost_codes    
  end

  def self.get_cost_information_for_products(cost_code, product_names)
    r = connection.post("/accounts/#{cost_code}/unit_price", product_names.to_json)
    response = JSON.parse(r.body).map{|o| o.symbolize_keys}
    return response
  end

  def self.get_unit_price(cost_code, product_name)
    response = get_cost_information_for_products(cost_code, [product_name]).first
    if response && response[:verified]
      return BigDecimal.new(response[:unitPrice])
    else
      return nil
    end    
  end

  def self.validate_product_name?(product_name)
    validate_single_value("/products/#{product_name}/verify")
  end

  def self.validate_cost_code?(cost_code)
    validate_single_value("/accounts/#{cost_code}/verify")
  end

  def self.filter_invalid_cost_codes(cost_codes)
    validate_multiple_values("/accounts/verify", {accounts: cost_codes})
  end

  def self.filter_invalid_product_names(product_names_list)
    validate_multiple_values("/catalogue/verify", {products: product_names_list})
  end

  def self.connection
    Faraday.new(:url => Rails.application.config.billing_facade_url, 
      headers: {'Content-Type': 'application/json', "Accept" => "application/json"})
  end
end
