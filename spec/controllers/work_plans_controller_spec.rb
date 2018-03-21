require 'rails_helper'

RSpec.describe WorkPlansController, type: :controller do
  before do
    @user = OpenStruct.new(email: 'jeff@sanger.ac.uk', groups: ['world'])
    @work_plan = create :work_plan, owner_email: @user.email
    @process = create(:process)

    allow(controller).to receive(:check_credentials)
    allow(controller).to receive(:current_user).and_return(@user)
  end

  context '#index' do
    it 'gets the index page' do
      get :index
    end
  end

  context '#destroy' do
    context 'when the work plan is in construction' do
      it 'destroys the work plan' do
        expect {
          post :destroy, params: { id: @work_plan.id }
        }.to change(WorkPlan, :count).by(-1)
        expect(flash[:notice]).to match(/deleted/)
      end
    end
    context 'when the work plan is not in construction' do
      before do
        @project = double('project', id: 1234)
        allow(StudyClient::Node).to receive(:find).with(@project.id).and_return([@project])
        @work_plan.update_attributes(project_id: @project.id)
        @work_order = create(:work_order, { work_plan: @work_plan, process: @process, status: 'active' })
      end

      it 'does not destroy the work plan' do
        expect {
          post :destroy, params: { id: @work_plan.id }
        }.to change(WorkPlan, :count).by(0)
        expect(flash[:notice]).to match(/cancelled/)
      end
    end
    context 'when the work plan is already cancelled' do
      before do
        @work_plan.update_attributes(cancelled: Time.now)
      end

      it 'does not destroy the work plan' do
        expect {
          post :destroy, params: { id: @work_plan.id }
        }.to change(WorkPlan, :count).by(0)
        expect(flash[:error]).to eq('This work plan has already been cancelled.')
      end
    end
  end

  context '#create' do
    it 'creates a new work plan' do
      expect {
        post :create
      }.to change(WorkPlan, :count).by(1)
    end
  end
end