require 'rails_helper'

RSpec.describe WorkPlansController, type: :controller do
  let(:user) { OpenStruct.new(email: 'jeff@sanger.ac.uk', groups: ['world']) }
  let(:pro) { create(:process) }

  before do
    allow(controller).to receive(:check_credentials)
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe '#index' do
    let(:instance_fields) { [:@in_construction_plans, :@active_plans, :@closed_plans, :@cancelled_plans] }

    context 'when there are work plans of various statuses' do
      let(:project_id) { 12 }
      let!(:in_construction_plans) {
        (1..2).map { create(:work_plan, owner_email: user.email) }
      }
      let!(:active_plans) {
        plans = (1..2).map { create(:work_plan, project_id: project_id, owner_email: user.email) }
        plans.each do |plan|
          create(:work_order, work_plan: plan, process: pro, status: 'active')
        end
        plans
      }
      let!(:closed_plans) {
        plans = (1..2).map { create(:work_plan, project_id: project_id, owner_email: user.email) }
        statuses = ['concluded', 'concluded']
        plans.zip(statuses).each do |plan, status|
          create(:work_order, work_plan: plan, process: pro, status: status)
        end
        plans
      }
      let!(:cancelled_plans) {
        (1..2).map { create(:work_plan, project_id: project_id, owner_email: user.email, cancelled: Time.now)}
      }
      let!(:other_peoples_plans) {
        [nil, Time.now].map do |cancelled|
          create(:work_plan, project_id: project_id, owner_email: 'fred@nowhere', cancelled: cancelled)
        end
      }

      before do
        get :index
      end

      it 'should set the in-construction plans correctly' do
        expect(controller.instance_variable_get(:@in_construction_plans)).to match_array(in_construction_plans)
      end
      it 'should set the active plans correctly' do
        expect(controller.instance_variable_get(:@active_plans)).to match_array(active_plans)
      end
      it 'should set the closed plans correctly' do
        expect(controller.instance_variable_get(:@closed_plans)).to match_array(closed_plans)
      end
      it 'should set the cancelled plans correctly' do
        expect(controller.instance_variable_get(:@cancelled_plans)).to match_array(cancelled_plans)
      end
    end

    context 'when there are no work plans of various statuses' do
      it 'should set the instance variables to empty arrays' do
        get :index
        instance_fields.each do |attr|
          expect(controller.instance_variable_get(attr)).to be_empty
        end
      end
    end
  end

  describe '#destroy' do
    let!(:work_plan) { create(:work_plan, owner_email: user.email) }

    context 'when the work plan is in construction' do
      it 'destroys the work plan' do
        expect {
          post :destroy, params: { id: work_plan.id }
        }.to change(WorkPlan, :count).by(-1)
        expect(flash[:notice]).to match(/deleted/)
      end
    end
    context 'when the work plan is not in construction' do
      let(:project) { double('project', id: 1234) }
      let!(:work_order) { create(:work_order, work_plan: work_plan, process: pro, status: 'active') }
      before do
        allow(StudyClient::Node).to receive(:find).with(project.id).and_return([project])
        work_plan.update_attributes(project_id: project.id)
      end

      it 'cancels the work plan' do
        expect {
          post :destroy, params: { id: work_plan.id }
        }.not_to change(WorkPlan, :count)

        expect(flash[:notice]).to match(/cancelled/)
        expect(WorkPlan.find(work_plan.id)).to be_cancelled
      end
    end
    context 'when the work plan is already cancelled' do
      before do
        work_plan.update_attributes(cancelled: Time.now)
      end

      it 'does not destroy the work plan' do
        expect {
          post :destroy, params: { id: work_plan.id }
        }.not_to change(WorkPlan, :count)
        expect(flash[:error]).to eq('This work plan has already been cancelled.')
      end
    end
  end

  describe '#create' do
    it 'creates a new work plan' do
      expect {
        post :create
      }.to change(WorkPlan, :count).by(1)
    end
  end
end