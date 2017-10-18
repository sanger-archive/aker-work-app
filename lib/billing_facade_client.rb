require 'faraday'

module BillingFacadeClient

  def self.validate_product_name?(product_name)
    r = connection.get("/products/#{product_name}/verify")
    return true if r.status==200
    Rails.logger.info "Attempting to validate product name #{product_name} returned status code #{r.status}"
    false
  end

  def self.filter_invalid_product_names(product_names_list)
    r = connection.post("/catalogue/verify", {products: product_names_list}.to_json )
    return [] if r.status==200
    response = JSON.parse(r.body)
    invalid_product_names = response.keys.select{|product_name| !response[product_name] }
    Rails.logger.info "Some of the product names were not valid: #{invalid_product_names}"
    return invalid_product_names
  end

  def self.connection
    Faraday.new(:url => Rails.application.config.billing_facade_url, 
      headers: {'Content-Type': 'application/json'})
  end
end
