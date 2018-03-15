require 'rails_helper'

RSpec.describe Catalogue, type: :model do
  describe "#create_with_products" do
    let(:lims_id) { "FOO" }
    let(:other_lims_id) { "BAR" }
    let(:product_uuid) { SecureRandom.uuid }
    let(:process_uuid) { SecureRandom.uuid }

    context 'when the catalogue is valid' do
      let(:params) do
        {
          lims_id: lims_id, url: "france", pipeline: "cells",
          processes: [
            { uuid: process_uuid, name: "QC", TAT: 5,
              process_module_pairings: [
                { from_step: nil, to_step: "Quantification", default_path: true},
                { from_step: "Genotyping HumGen SNP", to_step: nil, default_path: true},
                { from_step: "Quantification", to_step: "Genotyping CGP SNP", default_path: true},
              ]
            },
          ],
          products: [
            { uuid: product_uuid, name: "QC", description: "Lorem Ipsum", product_version: 1, availability: 1,
              requested_biomaterial_type: "blood", product_class: "genotyping",
              process_uuids: [process_uuid],
            }
          ]
        }
      end

      before do
        allow(BillingFacadeClient).to receive(:validate_process_module_name).and_return(true)
        @cat1 = Catalogue.create!(lims_id: lims_id, url: "somewhere", pipeline: "cells", current: true)
        @cat2 = Catalogue.create!(lims_id: other_lims_id, url: "somewhere else", pipeline: "cells", current: true)

        allow(Catalogue).to receive(:validate_processes).and_call_original
        allow(Catalogue).to receive(:validate_products).and_call_original

        @cat3 = Catalogue.create_with_products(params)
      end

      it "mark other catalogues as not current" do
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
        expect(product.uuid).to eq product_uuid
      end

      it "creates new products with processes" do
        product = Product.where(catalogue_id: @cat3.id)[0]
        expect(product.processes.length).to eq 1
        process = product.processes[0]
        expect(process.uuid).to eq process_uuid
        expect(process.name).to eq 'QC'
        expect(process.TAT).to eq 5
      end

      it "create new product processes" do
        product = Product.where(catalogue_id: @cat3.id)[0]
        process = product.processes[0]
        product_processes = Aker::ProductProcess.where(product_id: product.id)
        expect(product_processes.length).to eq 1
        expect(product_processes[0].aker_process_id).to eq process.id
        expect(product_processes[0].stage).to eq 0
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

      it 'should have called the validation methods' do
        expect(Catalogue).to have_received(:validate_products).with(params[:products])
        expect(Catalogue).to have_received(:validate_processes).with(params[:processes], params[:products])
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

  describe '#validate_products' do
    def raises_no_error
      expect { Catalogue.validate_products(product_params) }.not_to raise_error
    end
    def raises(message)
      expect { Catalogue.validate_products(product_params) }.to raise_error message
    end

    def make_product_hash
      uuid = SecureRandom.uuid
      {
        uuid: uuid,
        name: "Product #{uuid}",
        description: "Lorem Ipsum",
        product_version: 1,
        availability: 1,
        requested_biomaterial_type: "blood",
        product_class: "genotyping",
        process_uuids: [SecureRandom.uuid],
      }
    end

    context 'when the parameters are ok' do
      let(:product_params) { (0..2).map { make_product_hash } }
      it { raises_no_error }
    end

    context 'when there are products without uuids' do
      let(:product_params) { [make_product_hash, make_product_hash.except(:uuid)] }
      it { raises /uuid/i }
    end

    context 'when there are products with nil uuid' do
      let(:product_params) { [make_product_hash.merge(uuid: nil)] }
      it { raises /uuid/i }
    end

    context 'when there are duplicate uuids' do
      let(:product_params) do
        pps = (0..2).map { make_product_hash }
        pps[1][:uuid] = pps[0][:uuid]
        pps
      end

      it { raises /duplicate.*uuid/i }
    end

    context 'when there are products without names' do
      let(:product_params) { [make_product_hash, make_product_hash.except(:name)] }
      it { raises /name/i }
    end

    context 'when there are products with nil name' do
      let(:product_params) { [make_product_hash.merge(name: nil)] }
      it { raises /name/i }
    end

    context 'when there are duplicate names' do
      let(:product_params) do
        pps = (0..2).map { make_product_hash }
        pps[1][:name] = pps[0][:name]
        pps
      end

      it { raises /duplicate.*name/i }
    end
  end

  describe '#validate_processes' do
    def make_process
      uuid = SecureRandom.uuid
      {
        uuid: uuid,
        name: "Process #{uuid}",
        TAT: 5,
        process_module_pairings: []
      }
    end

    let(:valid_product_params) do
      uuid = SecureRandom.uuid
      [
        {
          uuid: uuid,
          name: "Product #{uuid}",
          description: "Lorem Ipsum",
          product_version: 1,
          availability: 1,
          requested_biomaterial_type: "blood",
          product_class: "genotyping",
          process_uuids: product_process_uuids,
        }
      ]
    end

    let(:product_process_uuids) { process_params&.map { |pro| pro[:uuid] } || [] }

    let(:product_params) { valid_product_params }
    let(:process_params) { (0...2).map { make_process } }

    def raises_no_error
      expect { Catalogue.validate_processes(process_params, product_params) }.not_to raise_error
    end
    def raises(message)
      expect { Catalogue.validate_processes(process_params, product_params) }.to raise_error message
    end

    context 'when the params are valid' do
      it { raises_no_error }
    end

    context 'when process params are missing' do
      let(:process_params) { nil }
      it { raises /processes/i }
    end

    context 'when processes are missing uuids' do
      let(:process_params) { [make_process, make_process.except(:uuid)] }
      it { raises /missing.*uuid/i }
    end

    context 'when processes contain duplicate uuids' do
      let(:process_params) do
        pps = (0..2).map { make_process }
        pps[2][:uuid] = pps[0][:uuid]
        pps
      end
      it { raises Regexp.new('uuid.*'+Regexp.escape(process_params[0][:uuid])) }
    end

    context 'when product_processes is missing' do
      let(:product_params) { [valid_product_params.first.except(:process_uuids)] }
      it { raises /process uuids/i }
    end

    context 'when product_processes is nil' do
      let(:product_process_uuids) { nil }
      it { raises /process uuids/i }
    end

    context 'when product_processes is empty' do
      let(:product_process_uuids) { [] }
      it { raises /process uuids/i }
    end

    context 'when there are process uuids not defined in the process params' do
      let(:product_process_uuids) { [SecureRandom.uuid] }
      it { raises /process uuids not defined/i }
    end

    context 'when the product contains duplicate process uuids' do
      let(:product_process_uuids) { (0..1).map { process_params.first[:uuid] } }
      it { raises /repeated process/i }
    end

  end

end
