require 'rails_helper'

RSpec.describe Catalogue, type: :model do
  describe "#create_with_products" do
    let (:lims_id) { "FOO" }
    let (:other_lims_id) { "BAR" }

    context "when creating" do
      before do
        @cat1 = Catalogue.create!(lims_id: lims_id, url: "somewhere", pipeline: "cells", current: true)
        @cat2 = Catalogue.create!(lims_id: other_lims_id, url: "somewhere else", pipeline: "cells", current: true)
        @cat3 = Catalogue.create_with_products(lims_id: lims_id, url: "france", pipeline: "cells",
          products: [{ id: 2, name: "QC", description: "Lorem Ipsum", product_version: 1, availability: 1,
          requested_biomaterial_type: "blood", product_class: "genotyping", processes: [
            { id: 2, name: "QC", stage: 1, TAT: 5, process_module_pairings: [
              { from_step: nil, to_step: "Quantification", default_path: true},
              { from_step: "Genotyping HumGen SNP", to_step: nil, default_path: true},
              { from_step: "Quantification", to_step: "Genotyping CGP SNP", default_path: true}
        ]}]}])
      end

      it "marks other catalogues as not current" do
        expect(Catalogue.find(@cat1.id).current).to be false
        expect(Catalogue.find(@cat2.id).current).to be true
        expect(Catalogue.find(@cat3.id).current).to be true
      end
      it "creates a new catalogue with products" do
        products = Product.where(catalogue_id: @cat3.id).all
        expect(products.length).to eq 1
        product = products.first
        expect(product.name).to eq 'QC'
        expect(product.description).to eq 'Lorem Ipsum'
        expect(product.product_class).to eq 'genotyping'
      end
    end
  end

  describe '#lims_id' do
    it 'should be sanitised' do
      expect(create(:catalogue, lims_id: "    My  \t  LIMS  \n").lims_id).to eq('My LIMS')
    end
  end

  describe 'validation' do
    it 'should not be valid without a lims_id' do
      expect(build(:catalogue, lims_id: nil)).not_to be_valid
    end

    it 'should not be valid with a blank lims_id after sanitisation' do
      expect(build(:catalogue, lims_id: "   \n  \t    ")).not_to be_valid
    end

    it 'should be valid with a lims_id after sanitisation' do
      expect(build(:catalogue, lims_id: "    My  \t  LIMS  \n")).to be_valid
    end
  end

end
