# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WorkOrderSerializer' do

  let(:work_order) { create(:work_order) }
  let(:work_order_serializer) { WorkOrderSerializer.new }

  before do
    @serialized_work_order = work_order_serializer.serialize(work_order)
  end

  it 'has a data field' do
    expect(@serialized_work_order[:data]).to be_kind_of(Array)
  end

end