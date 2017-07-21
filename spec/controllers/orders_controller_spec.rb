require 'rails_helper'

RSpec.describe OrdersController, type: :controller do
  def setup_user
    @request.env['devise.mapping'] = Devise.mappings[:user]
    groups = ["cowboys"]
    user = create(:user)
    sign_in user
    return user
  end

  describe "#show" do
    context "when the order belongs to the current user" do
      it "should work" do
        user = setup_user
        @wo = create(:work_order, user_id: user.id)

        get :show, params: { work_order_id: @wo.id, id: 'set' }

        expect(response).to have_http_status(:ok)
        expect(response.redirect_url).to be_nil
        expect(flash[:alert]).to be_nil
      end
    end

    context "when the order belongs to another user" do
      it "should fail authorisation" do
        user = setup_user
        user2 = create(:user, email: 'dirk@sanger.ac.uk')
        @wo = create(:work_order, user_id: user2.id)

        get :show, params: { work_order_id: @wo.id, id: 'set' }

        expect(response).to have_http_status(:found)
        expect(response.redirect_url).to be_present
        expect(flash[:alert]).to match(/not authori[sz]ed/)
      end
    end
  end

  describe "#update" do
    context "when there is nothing to update" do
      before do
        user = setup_user
        @wo = create(:work_order, user_id: user.id)
      end
      context "when work order is at set step" do
        it "should show error and stay on step when no set is selected" do
          put :update, params: { work_order_id: @wo.id, id: 'set'}
          expect(flash[:error]).to eq 'Please select a set to proceed.'

        end
      end
      context "when work order is at proposal step" do
        it "should show error and stay on step when no proposal is selected" do
          put :update, params: { work_order_id: @wo.id, id: 'proposal'}
          expect(flash[:error]).to eq 'Please select a proposal to proceed.'
          expect(UpdateOrderService).not_to receive(:new)
          expect(response.redirect_url).to be_nil
        end
        it "should show error and stay on step when a proposal not authorised for the user is selected" do
          allow(StudyClient::Node).to receive(:authorize!).and_raise(CanCan::AccessDenied)
          put :update, params: { work_order_id: @wo.id, work_order: { proposal_id: 1234 }, id: 'proposal'}
          expect(UpdateOrderService).not_to receive(:new)
          expect(response.redirect_url).to be_nil
        end
      end
      context "when work order is at product step" do
        it "should show error and stay on step when no product is selected" do
          put :update, params: { work_order_id: @wo.id, id: 'product', work_order: {comment:"", desired_date:""}}
          expect(flash[:error]).to eq 'Please select a product to proceed.'
          expect(UpdateOrderService).not_to receive(:new)
          expect(response.redirect_url).to be_nil
        end

        it "should show error and stay on step when no product is selected but comment or date is" do
          put :update, params: { work_order_id: @wo.id, id: 'product', work_order: {comment:"xxx", desired_date:""}}
          expect(flash[:error]).to eq 'Please select a product to proceed.'
          expect(UpdateOrderService).not_to receive(:new)
          expect(response.redirect_url).to be_nil
        end
      end
      context "when work order is at cost step" do
        it "should be redirected to the summary step" do
          put :update, params: { work_order_id: @wo.id, id: 'cost'}
          expect(UpdateOrderService).not_to receive(:new)
          expect(response.redirect_url).to include 'summary'
        end
      end
      context "when work order is at summary step" do
        it "should show error and stay on step when a proposal not authorised for the user is selected" do
          proposal = double(:proposal, id: 123)
          @wo.update_attributes(proposal_id: proposal.id)
          allow(StudyClient::Node).to receive(:find).with(proposal.id).and_return(proposal)
          allow(proposal).to receive(:first).and_return(proposal)
          allow(StudyClient::Node).to receive(:authorize!).and_raise(AkerPermissionGem::NotAuthorized)
          put :update, params: { work_order_id: @wo.id, id: 'summary' }
          expect(UpdateOrderService).not_to receive(:new)
        end
      end
    end

    context "when perform_step succeeds" do
      before do
        user = setup_user
        @wo = create(:work_order, user_id: user.id)
        allow(WorkOrder).to receive(:find).and_return(@wo)
        @uos = double('UpdateOrderService')
        allow(UpdateOrderService).to receive(:new).and_return(@uos)
        allow(@uos).to receive(:perform).and_return(true)
        allow(@wo).to receive(:save).and_return(true)

        wop = { original_set_uuid: 'bananas' }
        put :update, params: { work_order_id: @wo.id, id: 'set', work_order: wop }
      end

      it "should save the work order (via render_wizard)" do
        # When the step succeeds, render_wizard work_order is called, which tries to save the order
        expect(@wo).to have_received(:save)
      end

      it "should have performed the step" do
        expect(UpdateOrderService).to have_received(:new).with(anything, @wo, flash)
        expect(@uos).to have_received(:perform).with(:set)
      end

      it "should go to the next step" do
        expect(response).to have_http_status(:found)
        expect(response.redirect_url).to eq work_order_build_url(
          id: 'proposal',
          work_order_id: @wo.id
        )
      end

      it "should not have an authorisation error" do
        expect(flash[:alert]).to be_nil
      end
    end

    context "when perform_step fails" do
      before do
        user = setup_user
        @wo = create(:work_order, user_id: user.id)
        allow(WorkOrder).to receive(:find).and_return(@wo)
        @uos = double('UpdateOrderService')
        allow(UpdateOrderService).to receive(:new).and_return(@uos)
        allow(@uos).to receive(:perform).and_return(false)
        allow(@wo).to receive(:save).and_return(true)

        wop = { original_set_uuid: 'bananas' }
        put :update, params: { work_order_id: @wo.id, id: 'set', work_order: wop }
      end

      it "should not save the work order (via render_wizard)" do
        # When the step succeeds, render_wizard is called, which does not try to save the order
        expect(@wo).not_to have_received(:save)
      end

      it "should have tried to perform the step" do
        expect(UpdateOrderService).to have_received(:new).with(anything, @wo, flash)
        expect(@uos).to have_received(:perform).with(:set)
      end

      it "should stay on the same step" do
        expect(response).to have_http_status(:ok)
        expect(response.redirect_url).to be_nil
      end

      it "should not have an authorisation error" do
        expect(flash[:alert]).to be_nil
      end
    end

    context "when the order belongs to another user" do
      it "should fail authorisation" do
        user = setup_user
        user2 = create(:user, email: 'dirk@sanger.ac.uk')
        @wo = create(:work_order, user_id: user2.id)

        expect(UpdateOrderService).not_to receive(:new)

        put :update, params: { work_order_id: @wo.id, id: 'set', work_order: {} }

        expect(response).to have_http_status(:found)
        expect(response.redirect_url).to be_present
        expect(flash[:alert]).to match(/not authori[sz]ed/)
      end
    end
  end

end