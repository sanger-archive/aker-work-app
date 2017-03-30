require 'jwt'
require 'request_store'

class JWTSerializer < Faraday::Middleware

  def call(env)
    auth_hash = RequestStore.store[:x_authorisation]
    secret_key = Rails.application.config.jwt_secret_key
    exp = Time.now.to_i + Rails.application.config.jwt_exp_time
    nbf = Time.now.to_i - Rails.application.config.jwt_nbf_time

    payload = { data: auth_hash, exp: exp, nbf: nbf }
    env[:request_headers]["X-Authorisation"] = JWT.encode payload, secret_key, 'HS256'
    @app.call(env)
  end

end