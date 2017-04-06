class AuthRecord < ActiveRecord::Base
  self.abstract_class = true
  establish_connection "aker_auth_#{Rails.env}".to_sym
end
