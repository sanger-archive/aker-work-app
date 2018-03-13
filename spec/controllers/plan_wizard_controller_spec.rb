require 'rails_helper'
require 'ostruct'

RSpec.describe PlanWizardController, type: :controller do

  before do
    @user = OpenStruct.new(email: 'jeff@sanger.ac.uk', groups: ['world'])
    allow(controller).to receive(:check_credentials)
    allow(controller).to receive(:current_user).and_return(@user)
  end

  def mocked_set_with_authorized_materials
    set = double('set')
    mats = 5.times.map do
      mat = double('material')
      allow(mat).to receive(:id).and_return(SecureRandom.uuid)
      mat
    end

    allow(StampClient::Permission).to receive(:check_catch).and_return(true)
    allow(set).to receive(:materials).and_return(mats)
    set
  end

  describe "#show" do
    context "when the order belongs to the current user" do
      it "should work" do
        wp = create(:work_plan, owner_email: @user.email)

        get :show, params: { work_plan_id: wp.id, id: 'set' }

        expect(response).to have_http_status(:ok)
        expect(response.redirect_url).to be_nil
        expect(flash[:alert]).to be_nil
      end
    end

    context "when the order belongs to another user" do
      it "should fail authorisation" do
        user2 = OpenStruct.new(email: 'dirk@sanger.ac.uk', groups: ['world'])
        wp = create(:work_plan, owner_email: user2.email)

        get :show, params: { work_plan_id: wp.id, id: 'set' }

        expect(response).to have_http_status(:found)
        expect(response.redirect_url).to be_present
        expect(flash[:alert]).to match(/not authori[sz]ed/)
      end
    end
  end

  describe "#update" do
    context "when there is nothing to update" do
      before do
        @wp = create(:work_plan, owner_email: @user.email)
      end
      context "when work order is at set step" do
        it "should show error and stay on step when no set is selected" do
          put :update, params: { work_plan_id: @wp.id, id: 'set'}
          expect(flash[:error]).to eq 'Please select an option to proceed'

        end
      end
      context "when work order is at project step" do
        it "should show error and stay on step when no project is selected" do
          put :update, params: { work_plan_id: @wp.id, id: 'project'}
          expect(flash[:error]).to eq 'Please select an option to proceed'
          expect(UpdatePlanService).not_to receive(:new)
          expect(response.redirect_url).to be_nil
        end
        it "should show error and stay on step when a project not authorised for the user is selected" do
          allow(StudyClient::Node).to receive(:authorize!).and_raise(CanCan::AccessDenied)
          put :update, params: { work_plan_id: @wp.id, work_plan: { project_id: 1234 }, id: 'project'}
          expect(UpdatePlanService).not_to receive(:new)
          expect(response.redirect_url).to be_nil
        end
      end
      context "when work order is at product step" do
        it "should show error and stay on step when product is empty" do
          put :update, params: { work_plan_id: @wp.id, id: 'product', work_plan: {comment:"", desired_date:"", product_id:""}}
          expect(flash[:error]).to eq 'Please select a set in an earlier step.'
          expect(UpdatePlanService).not_to receive(:new)
          expect(response.redirect_url).to be_nil
        end

        it "should show error and stay on step when no product is selected" do
          put :update, params: { work_plan_id: @wp.id, id: 'product', work_plan: {comment:"", desired_date:""}}
          expect(flash[:error]).to eq 'Please select a set in an earlier step.'
          expect(UpdatePlanService).not_to receive(:new)
          expect(response.redirect_url).to be_nil
        end

        it "should show error and stay on step when no product is selected but comment or date is" do
          put :update, params: { work_plan_id: @wp.id, id: 'product', work_plan: {comment:"xxx", desired_date:""}}
          expect(flash[:error]).to eq 'Please select a set in an earlier step.'
          expect(UpdatePlanService).not_to receive(:new)
          expect(response.redirect_url).to be_nil
        end
      end
      context "when work order is at summary step" do
        before do
          project = double(:project, id: 123)
          @wp.update_attributes(project_id: project.id)
          allow(StudyClient::Node).to receive(:find).with(project.id).and_return(project)
          allow(StudyClient::Node).to receive(:where).with(project.id).and_return(project)
          allow(project).to receive(:first).and_return(project)
        end
        context "when a project not authorised for the user is selected" do
          before do
            allow(StudyClient::Node).to receive(:authorize!).and_raise(AkerPermissionGem::NotAuthorized)
          end
          it "should show error and stay on step" do
            put :update, params: { work_plan_id: @wp.id, id: 'dispatch' }
            expect(UpdatePlanService).not_to receive(:new)
          end
        end
        context "when a set that contains materials that I am not authorised as sender" do
          before do
            allow(StudyClient::Node).to receive(:authorize!)

            materials = 5.times.map{ double('material', id: SecureRandom.uuid)}
            set = double('set')
            allow(set).to receive(:materials).and_return(materials)
            allow(SetClient::Set).to receive(:find_with_materials).with(@wp.original_set_uuid).and_return([set])
            allow(StampClient::Permission).to receive(:check_catch).and_return(false)
            allow(StampClient::Permission).to receive(:unpermitted_uuids).and_return([])
          end
          it "should show error and stay on step" do
            put :update, params: { work_plan_id: @wp.id, id: 'dispatch' }
            expect(UpdatePlanService).not_to receive(:new)
          end
        end
      end
    end

    context "when perform_step succeeds" do
      before do
        @wp = create(:work_plan, owner_email: @user.email)
        allow(WorkPlan).to receive(:find).and_return(@wp)
        @ups = double('UpdatePlanService')
        allow(UpdatePlanService).to receive(:new).and_return(@ups)
        allow(@ups).to receive(:perform).and_return(true)
        allow(@wp).to receive(:save).and_return(true)

        wop = { original_set_uuid: 'bananas' }
        set = mocked_set_with_authorized_materials
        allow(SetClient::Set).to receive(:find_with_materials).with('bananas').and_return([set])
        put :update, params: { work_plan_id: @wp.id, id: 'set', work_plan: wop }
      end

      it "should save the work order (via render_wizard)" do
        # When the step succeeds, render_wizard work_order is called, which tries to save the order
        expect(@wp).to have_received(:save)
      end

      it "should have performed the step" do
        expect(UpdatePlanService).to have_received(:new).with(anything, @wp, false, flash)
        expect(@ups).to have_received(:perform)
      end

      it "should go to the next step" do
        expect(response).to have_http_status(:found)
        expect(response.redirect_url).to eq work_plan_build_url(
          id: 'project',
          work_plan_id: @wp.id
        )
      end

      it "should not have an authorisation error" do
        expect(flash[:alert]).to be_nil
      end
    end

    context "when perform_step fails" do
      before do
        @wp = create(:work_plan, owner_email: @user.email)
        allow(WorkOrder).to receive(:find).and_return(@wp)
        @ups = double('UpdatePlanService')
        allow(UpdatePlanService).to receive(:new).and_return(@ups)
        allow(@ups).to receive(:perform).and_return(false)
        allow(@wp).to receive(:save).and_return(true)

        wop = { original_set_uuid: 'bananas' }

        set = mocked_set_with_authorized_materials
        allow(SetClient::Set).to receive(:find_with_materials).with('bananas').and_return([set])

        put :update, params: { work_plan_id: @wp.id, id: 'set', work_plan: wop }
      end

      it "should not save the work order (via render_wizard)" do
        # When the step succeeds, render_wizard is called, which does not try to save the order
        expect(@wp).not_to have_received(:save)
      end

      it "should have tried to perform the step" do
        expect(UpdatePlanService).to have_received(:new).with(anything, @wp, false, flash)
        expect(@ups).to have_received(:perform)
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
        user2 = OpenStruct.new(email: 'dirk@sanger.ac.uk', groups: ['world'])
        @wp = create(:work_plan, owner_email: user2.email)

        expect(UpdatePlanService).not_to receive(:new)

        put :update, params: { work_plan_id: @wp.id, id: 'set', work_plan: {} }

        expect(response).to have_http_status(:found)
        expect(response.redirect_url).to be_present
        expect(flash[:alert]).to match(/not authori[sz]ed/)
      end
    end
  end
end
