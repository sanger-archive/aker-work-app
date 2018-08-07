# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WorkOrderSplitter::ByContainer' do

  let(:set_uuid) { SecureRandom.uuid }
  let(:work_order) { create(:work_order, set_uuid: set_uuid) }

  let(:first_container_uuids) do
    [
      "01cb5442-f7f1-4247-813e-8e7693b0b17d",
      "030a06d1-0309-4fb0-8c7f-571d5c8dcebc",
      "056ee9c0-0a9d-4213-bb68-0aacbc53653b",
      "06816dc3-f68e-4491-9b24-36a00e79133e",
      "082828d2-9635-4b7d-ba4c-46bddcb6692c"
    ]
  end

  let(:second_container_uuids) do
    [
      "086a5a64-4444-4e59-a80f-e3f4c4d42ded",
      "0a11302b-2ad6-469a-82c0-78b9c085f9f0",
      "0da6e13f-688a-459c-bf40-a341788662b4",
      "1341c67e-a88e-4476-9b7b-d53b1e5fb0ec",
      "13449bb3-1a82-4ddc-9969-db6de5f20b9e"
    ]
  end

  before :each do

    # Request to get all Materials in Set
    stub_request(:get, "http://external-server:3000/api/v1/sets/#{set_uuid}?include=materials")
      .to_return(status: 200, body: file_fixture("by_container_1.json").read, headers: { 'Content-Type' => 'application/vnd.api+json' })

    # Request to find all Containers for Materials in Set
    stub_request(:post, "http://external-server:5000/containers/search").
      with(
        body: "{\"where\":{\"slots.material\":{\"$in\":#{first_container_uuids + second_container_uuids}}}}".gsub(" ", "")
      )
      .to_return(status: 200, body: file_fixture("by_container_2.json").read, headers: { 'Content-Type' => 'application/vnd.api+json' })

    # Request for the schema
    stub_request(:get, "http://external-server:5000/containers/json_schema")
      .to_return(status: 200, body: file_fixture("container_schema.json").read, headers: { 'Content-Type' => 'application/vnd.api+json' })

    @bc = WorkOrderSplitter::ByContainer.new
  end

  describe '#splits' do

    it 'yields materials by container' do
      expect { |b| @bc.splits(work_order.decorate, &b) }.to yield_successive_args(first_container_uuids, second_container_uuids)
    end

  end

end