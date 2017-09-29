class ApplicationController < ActionController::Base

  #protect_from_forgery with: :exception

  include JWTCredentials

  include AkerPermissionControllerConfig

  helper_method :current_user

end
