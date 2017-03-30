require 'rails_helper'

RSpec.describe OrdersController, type: :controller do

	describe "JWT Auth Header" do
		context "when calling the set-service" do
			it "sets the authorization header by using the session" do
				work_order = create :work_order
				patch(:update, {:work_order_id => work_order.id, :id => 'set'}, { principle_user: 'MyUserData'})
				debugger
				#expect(:get => new_widget_path).to route_to(:controller => "widgets", :action => "new")
			end
		end

	end

end
