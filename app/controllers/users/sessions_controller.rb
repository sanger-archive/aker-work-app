class Users::SessionsController < Devise::SessionsController
  after_action :store_session_data, only: [:create]

  protected

  def store_session_data
    user_data = {
      email: current_user.email,
      groups: current_user.fetch_groups,
    }
    session[:user] = user_data
  end

end
