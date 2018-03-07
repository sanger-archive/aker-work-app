class ApplicationController < ActionController::Base
  # protect_from_forgery with: :exception

  include JWTCredentials

  include AkerPermissionControllerConfig

  before_action do
    RequestStore.store[:request_id] = request.request_id
  end

  helper_method :jwt_provided?
  helper_method :current_user
end
