require 'rails_helper'

RSpec.describe Product, type: :model do
  describe "#availability" do
    it "can be available" do
      product = build(:product, availability: :available)
      expect(product.available?).to eq true
      expect(product.suspended?).to eq false
      expect(product.availability).to eq 'available'
    end
    it "can be suspended" do
      product = build(:product, availability: :suspended)
      expect(product.available?).to eq false
      expect(product.suspended?).to eq true
      expect(product.availability).to eq 'suspended'
    end
    it "cannot be bananas" do
      expect { build(:product, availability: :bananas) }.to raise_error(ArgumentError)
    end
  end

  describe "#availability scopes" do
    context "when there are products" do
      before do
        @c1 = create(:catalogue)
        @p1 = create(:product, availability: :available, catalogue_id: @c1.id)
        @p2 = create(:product, availability: :suspended, catalogue_id: @c1.id)
        @p3 = create(:product, availability: :available, catalogue_id: @c1.id)
      end

      it "can find available products" do
        products = Product.available
        expect(products.length).to eq 2
        expect(products[0]).to eq @p1
        expect(products[1]).to eq @p3
      end

      it "can find suspended products" do
        products = Product.suspended
        expect(products.length).to eq 1
        expect(products.first).to eq @p2
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

  describe "#product_class scopes" do
    context "when there are products" do
      before do
        @c1 = create(:catalogue)
        @p1 = create(:product, product_class: :transcriptomics, catalogue_id: @c1.id)
        @p2 = create(:product, product_class: :transcriptomics, catalogue_id: @c1.id)
        @p3 = create(:product, product_class: :genotyping, catalogue_id: @c1.id)
      end

      it "can find products of class Transcriptomics" do
        products = Product.transcriptomics
        expect(products.length).to eq 2
        expect(products[0]).to eq @p1
        expect(products[1]).to eq @p2
      end

      it "can find products of class Genotyping" do
        products = Product.genotyping
        expect(products.length).to eq 1
        expect(products.first).to eq @p3
      end
    end
  end
end
