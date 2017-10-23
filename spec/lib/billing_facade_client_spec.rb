require 'rails_helper'

RSpec.describe('BillingFacadeClient') do
  let(:billing_url) { Rails.application.config.billing_facade_url }
  context '#validate_single_value' do

    let(:path) { '/anypath'}
    let(:url) {billing_url + path }

    context 'when the status received is 200' do
      setup do
        stub_request(:get, url).
          to_return(status: 200, body: {verified: true }.to_json)        
      end
      it 'returns the value of the field verified' do
        expect(BillingFacadeClient.validate_single_value(path)).to eq(true)
      end
    end

    context 'when the status received is not 200' do
      setup do
        stub_request(:get, url).
          to_return(status: 404, body: nil)
      end      
      it 'returns false' do
        expect(BillingFacadeClient.validate_single_value(path)).to eq(false)
      end
    end
  end
  context '#validate_multiple_values' do

    let(:path) { '/anypath'}
    let(:url) {billing_url + path }
    let(:params) { ['a','b','c']}

    context 'when the status received is not 200' do
      it 'returns the list of keys of the object whom value is false' do
        stub_request(:post, url).with(body: params.to_json).
          to_return(status: 400, body: {'a': false, 'b': true, 'c': false }.to_json)        
        expect(BillingFacadeClient.validate_multiple_values(path, params)).to eq(['a','c'])
      end
      it 'returns an empty list when the object obtained is empty' do
        stub_request(:post, url).with(body: params.to_json).
          to_return(status: 400, body: {}.to_json)        
        expect(BillingFacadeClient.validate_multiple_values(path, params)).to eq([])        
      end
      it 'returns an empty list when the object obtained does not have invalid values' do
        stub_request(:post, url).with(body: params.to_json).
          to_return(status: 400, body: {'a': true, 'b': true, 'c': true }.to_json)        
        expect(BillingFacadeClient.validate_multiple_values(path, params)).to eq([])        
      end
    end

    context 'when the status received is 200' do
      setup do
        stub_request(:post, url).with(body: params.to_json).
          to_return(status: 200, body: {'a': false, 'b': true, 'c': false }.to_json)
      end      
      it 'returns an empty list' do
        expect(BillingFacadeClient.validate_multiple_values(path, params)).to eq([])
      end
    end

  end
  context '#get_cost_information_for_products' do
    let(:cost_code) {'code'}
    let(:url) {billing_url + "/accounts/#{cost_code}/unit_price"}
    let(:product_names) { ['a','b','c'] }

    it 'performs a call to the unit price action for the proposal' do
      data = [{'my': true, 'data': false}]
      stub_request(:post, url).with(body: product_names.to_json).
        to_return(status: 200, body: data.to_json)
      expect(BillingFacadeClient.get_cost_information_for_products(cost_code, product_names)).to eq(data)
    end
  end
  context '#get_unit_price' do
    let(:cost_code) {'code'}
    let(:product_name) {'a product name'}
    let(:unit_price) { "33.3" }
    context 'when there is no unit price defined for the pair [cost code, product name]' do
      setup do
        allow(BillingFacadeClient).to receive(:get_cost_information_for_products)
          .with(cost_code, [product_name])
            .and_return([])
      end

      it 'returns nil ' do
        expect(BillingFacadeClient.get_unit_price(cost_code, product_name)).to eq(nil)
      end
    end
    context 'when there is a unit price defined' do
      context 'when the price is not verified by the billing service' do
        setup do
          allow(BillingFacadeClient).to receive(:get_cost_information_for_products)
            .with(cost_code, [product_name])
              .and_return([{unitPrice: unit_price, verified: false}])
        end

        it 'returns nil' do
          expect(BillingFacadeClient.get_unit_price(cost_code, product_name)).to eq(nil)
        end
      end
      context 'when the price is verified by the billing service' do
        setup do
          allow(BillingFacadeClient).to receive(:get_cost_information_for_products)
            .with(cost_code, [product_name])
              .and_return([{unitPrice: unit_price, verified: true}])
        end

        it 'returns the unit price' do
          expect(BillingFacadeClient.get_unit_price(cost_code, product_name)).to eq(BigDecimal.new(unit_price))
        end
        it 'is a BigDecimal data type' do
          expect(BillingFacadeClient.get_unit_price(cost_code, product_name).kind_of? BigDecimal).to eq(true)
        end
      end
    end
  end
  context '#validate_product_name?' do
    it 'validates using the url' do
      expect(BillingFacadeClient).to receive(:validate_single_value).with('/products/product1/verify')
      BillingFacadeClient.validate_product_name?('product1')
    end
  end
  context '#validate_cost_code?' do
    it 'validates using the url' do
      expect(BillingFacadeClient).to receive(:validate_single_value).with('/accounts/cost1/verify')
      BillingFacadeClient.validate_cost_code?('cost1')
    end    
  end
  context '#filter_invalid_cost_codes' do
    it 'validates using the url' do
      cost_codes = ['a','b']
      expect(BillingFacadeClient).to receive(:validate_multiple_values).with('/accounts/verify', {accounts: cost_codes})
      BillingFacadeClient.filter_invalid_cost_codes(cost_codes)
    end    
  end
  context '#filter_invalid_product_names' do
    it 'validates using the url' do
      product_names = ['a','b']
      expect(BillingFacadeClient).to receive(:validate_multiple_values).with('/catalogue/verify', {products: product_names})
      BillingFacadeClient.filter_invalid_product_names(product_names)
    end        
  end
  context '#connection' do
    it 'creates a new connection' do
      expect(Faraday).to receive(:new)
      BillingFacadeClient.connection
    end
  end
end