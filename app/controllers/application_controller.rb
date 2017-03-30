class ApplicationController < ActionController::Base
	before_action :apply_credentials

	private

	def apply_credentials
		RequestStore.store[:x_authorisation] = get_principle_user
	end

	def get_principle_user
		session[:principle_user]
	end

end
