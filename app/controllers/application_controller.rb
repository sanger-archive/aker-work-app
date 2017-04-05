class ApplicationController < ActionController::Base
  # Checks authorization has been performed for every action
  # Throws an error if not
  # See https://github.com/ryanb/cancan/wiki/Ensure-Authorization
  check_authorization

  before_action :apply_credentials

  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.json { head :forbidden, content_type: 'text/html' }
      format.html { redirect_to root_path, alert: exception.message }
      format.js   { head :forbidden, content_type: 'text/html' }
    end
  end

  private

  def apply_credentials
    RequestStore.store[:x_authorisation] = get_user
  end

  def get_user
    session["user"]
  end

  rescue_from DeviseLdapAuthenticatable::LdapException do |exception|
      render :text => exception, :status => 500
  end
end
