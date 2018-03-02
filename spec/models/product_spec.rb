require 'rails_helper'

RSpec.describe Product, type: :model do
  let(:catalogue) { create(:catalogue) }

  describe "#availability" do
    it "can be available" do
      product = build(:product, availability: true)
      expect(product.availability).to eq true
    end
    it "can be suspended" do
      product = build(:product, availability: false)
      expect(product.availability).to eq false
    end
    it "default is true" do
      product = build(:product)
      expect(product.availability).to eq true
    end
  end

  describe "#availability scopes" do
    context "when there are products" do
      let!(:products) do
        [true, false, true].map { |av| create(:product, availability: av, catalogue: catalogue) }
      end

      it "can find available products" do
        expect(Product.available).to eq([products[0], products[2]])
      end

      it "can find suspended products" do
        expect(Product.suspended).to eq([products[1]])
      end
    end
  end

  describe "#product_class" do
    it "can be DNA Sequencing" do
      product = build(:product, product_class: :dna_sequencing)
      expect(product.dna_sequencing?).to eq true
      expect(product.genotyping?).to eq false
      expect(product.product_class).to eq 'dna_sequencing'
    end
    it "can be Genotyping" do
      product = build(:product, product_class: :genotyping)
      expect(product.genotyping?).to eq true
      expect(product.transcriptomics?).to eq false
      expect(product.product_class).to eq 'genotyping'
    end
    it "can be Transcriptomics" do
      product = build(:product, product_class: :transcriptomics)
      expect(product.transcriptomics?).to eq true
      expect(product.cell_line_creation?).to eq false
      expect(product.product_class).to eq 'transcriptomics'
    end
    it "can be Cell Line Creation" do
      product = build(:product, product_class: :cell_line_creation)
      expect(product.cell_line_creation?).to eq true
      expect(product.dna_sequencing?).to eq false
      expect(product.product_class).to eq 'cell_line_creation'
    end
    it "cannot be nonesense" do
      expect { build(:product, product_class: :nonesense) }.to raise_error(ArgumentError)
    end
  end

  describe '#product_class scopes' do
    context "when there are products" do
      let!(:products) do
        [:transcriptomics, :transcriptomics, :genotyping].map { |pc| create(:product, product_class: pc, catalogue: catalogue) }
      end

      it "can find products of class Transcriptomics" do
        expect(Product.transcriptomics).to eq(products[0...2])
      end

      it "can find products of class Genotyping" do
        expect(Product.genotyping).to eq([products[2]])
      end
    end
  end

  describe '#processes' do
    let(:product) { create(:product, catalogue: catalogue) }

    it 'should be in the order specified by the process stage' do
      pros = (1...4).map { |i| create(:process, name: "process #{i}") }
      links = pros.each_with_index.map { |pro, i| create(:product_process, product: product, aker_process: pro, stage: i) }
      expect(product.processes.reload).to eq(pros)
    end
    it 'should be in the different order specified by the process stage' do
      pros = (1...4).map { |i| create(:process, name: "process #{i}") }
      links = pros.each_with_index.map { |pro, i| create(:product_process, product: product, aker_process: pro, stage: 4-i) }
      expect(product.processes.reload).to eq(pros.reverse)
    end
  end
end
