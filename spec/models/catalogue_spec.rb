require 'rails_helper'

RSpec.describe Catalogue, type: :model do
  describe "#create_with_products" do
    let (:lims_id) { "FOO" }
    let (:other_lims_id) { "BAR" }

    context "when creating" do
      before do
        @cat1 = Catalogue.create!(lims_id: lims_id, url: "somewhere", pipeline: "cells", current: true)
        @cat2 = Catalogue.create!(lims_id: other_lims_id, url: "somewhere else", pipeline: "cells", current: true)
        @cat3 = Catalogue.create_with_products(
          lims_id: lims_id, url: "france", pipeline: "cells", 'products' => [
            { name: "Cake", product_version: "2", description: "delicious", availability: "available",
              TAT: 3, requested_biomaterial_type: "flour", product_class: "DNA Sequencing" }
          ]
        )
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
        expect(product.name).to eq "Cake"
        expect(product.description).to eq "delicious"
        expect(product.product_class).to eq 'dna_sequencing'
      end

    end

  end
end
