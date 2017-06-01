require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do

  describe "JWT Auth Header" do
    context "when calling the set-service" do
      it "sets the authorization header by using the session" do
        principle_user = {:data => 'some_info'}
        jwt = JWTSerializer.generate_jwt(principle_user)
        allow(JWTSerializer).to receive(:generate_jwt).and_return(jwt)
        RequestStore.store[:x_authorisation] = principle_user
        srequ = stub_request(:get, "#{Rails.configuration.set_url}/sets").
           with(:headers => {'Accept'=>'application/vnd.api+json',
             'Content-Type'=>'application/vnd.api+json',
             'X-Authorisation'=> jwt}).
           to_return(:status => 200, :body => "", :headers => {})

        SetClient::Set.all
        assert_requested(srequ)
      end
    end
  end

end
