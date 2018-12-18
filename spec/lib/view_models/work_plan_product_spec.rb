require 'rails_helper'

RSpec.describe 'ViewModels::WorkPlanProduct' do

  let(:work_plan) { create(:work_plan, :with_original_set).decorate }
  let(:view_model) { ViewModels::WorkPlanProduct.new(work_plan: work_plan) }
  let(:set) { build(:set, id: work_plan.original_set_uuid) }

  describe 'class exists' do
    it 'should allow you to initialize the WorkPlanSet class' do
      expect{ view_model }.not_to raise_error
    end
  end

  describe 'attributes' do
    it 'has work_plan' do
      expect(view_model.work_plan).to eq(work_plan)
    end
  end

  describe '#form_enabled?' do
    context 'when WorkPlan is in construction' do
      it 'is true' do
        expect(view_model.form_enabled?).to be true
      end
    end

    context 'when WorkPlan is not in construction' do
      let(:work_plan) { create(:work_plan, status: :active) }

      it 'is false' do
        expect(view_model.form_enabled?).to be false
      end
    end
  end

  describe '#number_of_samples' do
    it 'is the number of samples in the Original Set' do
      allow(work_plan).to receive(:original_set).and_return(set)
      expect(view_model.number_of_samples).to eql(set.meta[:size])
    end
  end

  describe '#work_plan_product_id' do
    it 'is the selected WorkPlan\'s product_id' do
      expect(view_model.work_plan_product_id).to eql(work_plan.product_id)
    end
  end

  describe '#current_catalogues_with_products' do
    let!(:catalogues) { create_list(:catalogue_with_products, 2) }

    it 'is an array of [pipeline_name, [...products]]' do
      current_catalogues     = view_model.current_catalogues_with_products
      empty_catalogue        = current_catalogues.first
      actual_first_catalogue = current_catalogues.second

      expect(current_catalogues.size).to eq 3
      expect(empty_catalogue).to eq(["", [""]])
    end

  end

end