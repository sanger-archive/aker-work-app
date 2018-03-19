require 'rails_helper'

RSpec.describe Product, type: :model do
  let(:catalogue) { create(:catalogue) }

  describe "#availability" do
    it "can be available" do
      product = build(:product, availability: true)
      expect(product.availability).to eq true
      expect(product.available?).to eq true
      expect(product.suspended?).to eq false
    end
    it "can be suspended" do
      product = build(:product, availability: false)
      expect(product.availability).to eq false
      expect(product.available?).to eq false
      expect(product.suspended?).to eq true
    end
    it "default is true" do
      product = build(:product)
      expect(product.availability).to eq true
      expect(product.available?).to eq true
      expect(product.suspended?).to eq false
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
