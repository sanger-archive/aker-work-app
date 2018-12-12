require 'rails_helper'

RSpec.describe 'ViewModels::WorkPlanProcess' do

  let(:product) { create(:product_with_processes)}
  let(:process) { product.processes.first }
  let(:work_plan) { create(:work_plan, product: product) }
  let(:work_orders) { create_list(:work_order, 3, process_id: process.id, work_plan: work_plan) }
  let(:view_model) { ViewModels::WorkPlanProcess.new(work_plan: work_plan, work_orders: work_orders, process: process) }

  describe 'WorkPlanProcess#new' do
    it 'initializes the class' do
      expect{ view_model }.not_to raise_error
    end
  end

  describe '#work_orders' do
    it 'is a list of ViewModels::WorkOrder objects' do
      expect(view_model.work_orders).to all be_an_instance_of(ViewModels::WorkOrder)
    end
  end

  describe '#process_name' do
    it 'is the name of the Process' do
      expect(view_model.process_name).to eql(process.name)
    end
  end

  describe '#show_start_jobs_button?' do

    context 'when this is the last Process in the Product' do
      it 'is false' do
        expect(view_model.show_start_jobs_button?).to be false
      end
    end

    context 'when there are Jobs that have been concluded but haven\'t been forwarded' do

      before do
        work_orders.first.jobs = create_list(:completed_job, 3) + create_list(:started_job, 3) + create_list(:forwarded_job, 3)
        work_orders.first.save!
      end

      it 'is true' do
        expect(view_model.show_start_jobs_button?).to be true
      end

    end

    context 'when there are no Jobs that have been concluded but haven\'t been forwarded' do

      before do
        work_orders.first.jobs = create_list(:forwarded_job, 3) # Only *forwarded* jobs
        work_orders.first.save!
      end

      it 'is false' do
        expect(view_model.show_start_jobs_button?).to be false
      end

    end

  end

  describe '#form_enabled?' do

    context 'when a Work Order has been created for this Process' do
      it 'is false' do
        expect(view_model.form_enabled?).to be false
      end
    end

    context 'when a Work Order has not yet been created for this Process' do
      let(:work_orders) { [] }

      it 'is true' do
        expect(view_model.form_enabled?).to be true
      end
    end

  end

end