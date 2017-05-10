class ApplicationController < ActionController::Base

  protect_from_forgery with: :exception

  include JWTCredentials
  include AkerAuthenticationGem::AuthController

  include AkerPermissionControllerConfig

  rescue_from StandardError do |e|
    debugger
  end
end