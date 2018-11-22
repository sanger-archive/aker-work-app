require 'rails_helper'
require 'ostruct'
require 'set'

RSpec.describe 'UbwClient' do
  let(:prices) do
    [ [ 'alpha', 'S0000', '100.50' ], ['alpha', 'S0001', '201.00'],
      [ 'beta', 'S0001', '3.5' ], ['beta', 'S0000', '1.5'],
    ].map do |name, cost_code, price|
      OpenStruct.new(module_name: name, cost_code: cost_code, unit_price: BigDecimal.new(price))
    end
  end

  before do
    allow(Ubw::Price).to receive(:where) do |params|
      module_names = params[:module_name]
      cost_code = params[:cost_code]
      if module_names.is_a? String
        module_names = Set[module_names]
      end
      prices.select do |price|
        (!module_names || module_names.include?(price.module_name)) &&
        (!cost_code || cost_code==price.cost_code)
      end
    end
  end

  describe '#get_unit_prices' do
    context 'when passed a valid module name' do
      it 'should return a hash containing the correct price' do
        expected = { 'alpha' => BigDecimal.new('201.00') }
        expect(UbwClient::get_unit_prices('alpha', 'S0001')).to eq(expected)
      end
    end

    context 'when passed a invalid module name' do
      it 'should return an empty hash' do
        expect(UbwClient::get_unit_prices('omega', 'S0001')).to eq({})
      end
    end

    context 'when passed an invalid cost code' do
      it 'should return an empty hash' do
        expect(UbwClient::get_unit_prices('alpha', 'S9999')).to eq({})
      end
    end

    context 'when passed an array' do
      it 'should return a hash containing the correct prices' do
        expected = { 'alpha' => BigDecimal.new('100.50'), 'beta' => BigDecimal.new('1.5') }
        expect(UbwClient::get_unit_prices(['alpha', 'beta', 'omega'], 'S0000')).to eq(expected)
      end
    end
  end

  describe '#missing_unit_prices' do
    context 'when passed a valid module name' do
      it 'should return an empty set' do
        expect(UbwClient::missing_unit_prices('alpha', 'S0001')).to be_empty
      end
    end

    context 'when passed a invalid module name' do
      it 'should return a set containing the module name' do
        expect(UbwClient::missing_unit_prices('omega', 'S0001')).to eq(Set['omega'])
      end
    end

    context 'when passed an invalid cost code' do
      it 'should return a set containing the module name' do
        expect(UbwClient::missing_unit_prices('alpha', 'S9999')).to eq(Set['alpha'])
      end
    end

    context 'when passed an array' do
      it 'should return a set of module names without correct prices' do
        expect(UbwClient::missing_unit_prices(['alpha', 'beta', 'omega'], 'S0000')).to eq(Set['omega'])
      end
    end
  end

  describe '#valid_module_names' do
    context 'when passed a valid module name' do
      it 'should return a set containing the module name' do
        expect(UbwClient::valid_module_names('alpha')).to eq(Set['alpha'])
      end
    end

    context 'when passed an invalid module name' do
      it 'should return an empty set' do
        expect(UbwClient::valid_module_names('omega')).to be_empty
      end
    end

    context 'when passed an array' do
      it 'should return a set containing the valid module names' do
        expect(UbwClient::valid_module_names(['alpha', 'beta', 'omega'])).to eq(Set['alpha', 'beta'])
      end
    end
  end


  describe '#invalid_module_names' do
    context 'when passed a valid module name' do
      it 'should return an empty set' do
        expect(UbwClient::invalid_module_names('alpha')).to be_empty
      end
    end

    context 'when passed an invalid module name' do
      it 'should return a set containing the module name' do
        expect(UbwClient::invalid_module_names('omega')).to eq(Set['omega'])
      end
    end

    context 'when passed an array' do
      it 'should return a set containing the invalid module names' do
        expect(UbwClient::invalid_module_names(['alpha', 'beta', 'omega'])).to eq(Set['omega'])
      end
    end
  end

end
