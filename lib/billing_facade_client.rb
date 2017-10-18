require 'faraday'

module BillingFacadeClient

  def self.validate_single_value(url)
    r = connection.get(url)
    return false unless r.status == 200
    response = JSON.parse(r.body)
    return response["verified"]    
  end

  def self.validate_multiple_values(url, params)
    r = connection.post("/accounts/verify", params.to_json )
    return [] if r.status==200
    response = JSON.parse(r.body)
    invalid_cost_codes = response.keys.select{|cost_code| !response[cost_code] }
    return invalid_cost_codes    
  end    

  def self.get_unit_price(product_name, cost_code)
    r = connection.get("/products/#{product_name}/accounts/#{cost_code}/unit_price")
    return false unless r.status == 200
    response = JSON.parse(r.body)
    if response["verified"]
      return response["unitPrice"]
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
