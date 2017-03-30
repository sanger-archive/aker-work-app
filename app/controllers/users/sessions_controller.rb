class Users::SessionsController < Devise::SessionsController
  after_action :store_session_data, only: [:create]

  protected

  def store_session_data
    session[:user] = current_user
  end

end
