require 'rails_helper'

RSpec.describe Catalogue, type: :model do
  describe "#create_with_products" do
    let (:lims_id) { "FOO" }
    let (:other_lims_id) { "BAR" }

    context "when creating" do
      before do
        allow(BillingFacadeClient).to receive(:validate_process_module_name).and_return(true)
        @cat1 = Catalogue.create!(lims_id: lims_id, url: "somewhere", pipeline: "cells", current: true)
        @cat2 = Catalogue.create!(lims_id: other_lims_id, url: "somewhere else", pipeline: "cells", current: true)
        @cat3 = Catalogue.create_with_products(lims_id: lims_id, url: "france", pipeline: "cells",
          products: [{ id: 2, name: "QC", description: "Lorem Ipsum", product_version: 1, availability: 1,
          requested_biomaterial_type: "blood", product_class: "genotyping", processes: [
            { id: 2, name: "QC", TAT: 5, process_module_pairings: [
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

      it "creates new products with processes" do
        product = Product.where(catalogue_id: @cat3.id)[0]
        expect(product.processes.length).to eq 1
        process = product.processes[0]
        expect(process.external_id).to eq 2
        expect(process.name).to eq 'QC'
        expect(process.TAT).to eq 5
      end

      it "create new product processes" do
        product = Product.where(catalogue_id: @cat3.id)[0]
        process = product.processes[0]
        product_processes = Aker::ProductProcess.where(product_id: product.id)
        expect(product_processes.length).to eq 1
        expect(product_processes[0].aker_process_id).to eq process.id
        expect(product_processes[0].stage).to eq 1
      end

      it "creates new process modules" do
        process = Product.where(catalogue_id: @cat3.id)[0].processes[0]
        modules = Aker::ProcessModule.where(aker_process_id: process.id)
        expect(modules.length).to eq 3
        expect(modules.map(&:name)).to eq ["Quantification", "Genotyping HumGen SNP", "Genotyping CGP SNP"]
        pairings =  Aker::ProcessModulePairings.where(aker_process_id: process.id)
        module1 = Aker::ProcessModule.find_by(name: "Quantification")
        module2 = Aker::ProcessModule.find_by(name: "Genotyping HumGen SNP")
        module3 = Aker::ProcessModule.find_by(name: "Genotyping CGP SNP")
        expect(pairings[0]).to have_attributes(from_step_id: nil, to_step_id: module1.id, aker_process_id: process.id)
        expect(pairings[1]).to have_attributes(from_step_id: module2.id, to_step_id: nil, aker_process_id: process.id)
        expect(pairings[2]).to have_attributes(from_step_id: module1.id, to_step_id: module3.id, aker_process_id: process.id)
      end
    end
  end

  describe "#validate_module_name" do
    it "should return true when the name is valid" do
      allow(BillingFacadeClient).to receive(:validate_process_module_name).and_return(true)
      expect(Catalogue.validate_module_name('good name')).to eq true
    end
    it "should return false when the name is invalue" do
      allow(BillingFacadeClient).to receive(:validate_process_module_name).and_return(false)
      expect(Catalogue.validate_module_name('bad name')).to eq false
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
