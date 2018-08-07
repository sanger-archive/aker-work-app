# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WorkOrderSplitter' do

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

  let(:work_order) { create(:work_order) }

  let(:splitter) { WorkOrderSplitter::Splitter.new }

  before :each do

    # Set Creation
    stub_request(:post, "http://external-server:3000/api/v1/sets")
      .to_return(
        { status: 201, body: file_fixture("work_order_splitter_1.json").read, headers: { 'Content-Type'=>'application/vnd.api+json' } },
        { status: 201, body: file_fixture("work_order_splitter_2.json").read, headers: { 'Content-Type'=>'application/vnd.api+json' } })

    # Add the Materials
    stub_request(:post, "http://external-server:3000/api/v1/sets/28d7c0e2-9935-41b1-a806-e9b22324d41f/relationships/materials")
      .with(body: "{\"data\":[{\"id\":\"01cb5442-f7f1-4247-813e-8e7693b0b17d\",\"type\":\"materials\"},{\"id\":\"030a06d1-0309-4fb0-8c7f-571d5c8dcebc\",\"type\":\"materials\"},{\"id\":\"056ee9c0-0a9d-4213-bb68-0aacbc53653b\",\"type\":\"materials\"},{\"id\":\"06816dc3-f68e-4491-9b24-36a00e79133e\",\"type\":\"materials\"},{\"id\":\"082828d2-9635-4b7d-ba4c-46bddcb6692c\",\"type\":\"materials\"}]}")
      .to_return(status: 200, body: "", headers: { 'Content-Type'=>'application/vnd.api+json' })

    stub_request(:post, "http://external-server:3000/api/v1/sets/28d7c0e2-9935-41b1-a806-e9b22324d42d/relationships/materials")
      .with(body: "{\"data\":[{\"id\":\"086a5a64-4444-4e59-a80f-e3f4c4d42ded\",\"type\":\"materials\"},{\"id\":\"0a11302b-2ad6-469a-82c0-78b9c085f9f0\",\"type\":\"materials\"},{\"id\":\"0da6e13f-688a-459c-bf40-a341788662b4\",\"type\":\"materials\"},{\"id\":\"1341c67e-a88e-4476-9b7b-d53b1e5fb0ec\",\"type\":\"materials\"},{\"id\":\"13449bb3-1a82-4ddc-9969-db6de5f20b9e\",\"type\":\"materials\"}]}")
      .to_return(status: 200, body: "", headers: {})

    # Lock the Sets
    stub_request(:patch, "http://external-server:3000/api/v1/sets/28d7c0e2-9935-41b1-a806-e9b22324d41f")
      .with(body: "{\"data\":{\"id\":\"28d7c0e2-9935-41b1-a806-e9b22324d41f\",\"type\":\"sets\",\"attributes\":{\"owner_id\":\"owner@sanger.ac.uk\",\"locked\":true}}}")
      .to_return(status: 200, body: "", headers: {})

    stub_request(:patch, "http://external-server:3000/api/v1/sets/28d7c0e2-9935-41b1-a806-e9b22324d42d")
      .with(body: "{\"data\":{\"id\":\"28d7c0e2-9935-41b1-a806-e9b22324d42d\",\"type\":\"sets\",\"attributes\":{\"owner_id\":\"owner@sanger.ac.uk\",\"locked\":true}}}")
      .to_return(status: 200, body: "", headers: {})

    allow(splitter).to receive(:splits).and_yield(first_container_uuids).and_yield(second_container_uuids)
  end

  describe '#split' do

    it 'creates a Job for each split' do
      expect { splitter.split(work_order) }.to change { work_order.jobs.count }.from(0).to(2)
      expect(work_order.jobs.first.input_set_uuid).to eql("28d7c0e2-9935-41b1-a806-e9b22324d41f")
      expect(work_order.jobs.second.input_set_uuid).to eql("28d7c0e2-9935-41b1-a806-e9b22324d42d")
    end

    context 'when it fails half way through' do

      before :each do
        # Create the first Set
        stub_request(:post, "http://external-server:3000/api/v1/sets")
          .to_return(
            { status: 201, body: file_fixture("work_order_splitter_1.json").read, headers: { 'Content-Type'=>'application/vnd.api+json' } }
          )
          .to_raise(JsonApiClient::Errors::ApiError)

        # Add the Materials
        stub_request(:post, "http://external-server:3000/api/v1/sets/28d7c0e2-9935-41b1-a806-e9b22324d41f/relationships/materials")
          .with(body: "{\"data\":[{\"id\":\"01cb5442-f7f1-4247-813e-8e7693b0b17d\",\"type\":\"materials\"},{\"id\":\"030a06d1-0309-4fb0-8c7f-571d5c8dcebc\",\"type\":\"materials\"},{\"id\":\"056ee9c0-0a9d-4213-bb68-0aacbc53653b\",\"type\":\"materials\"},{\"id\":\"06816dc3-f68e-4491-9b24-36a00e79133e\",\"type\":\"materials\"},{\"id\":\"082828d2-9635-4b7d-ba4c-46bddcb6692c\",\"type\":\"materials\"}]}")
          .to_return(status: 200, body: "", headers: { 'Content-Type'=>'application/vnd.api+json' })

        # Oh no! Something went wrong! Delete the Set that was created!
        stub_request(:delete, "http://external-server:3000/api/v1/sets/28d7c0e2-9935-41b1-a806-e9b22324d41f")
          .to_return(status: 204, body: "", headers: { 'Content-Type' => 'application/vnd.api+json' })
      end

      it 'doesn\'t create any Jobs (and deletes any created sets)' do
        expect { splitter.split(work_order) }.to change { work_order.jobs.count }.by(0)
      end

    end
  end

end