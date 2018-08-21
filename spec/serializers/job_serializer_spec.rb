# frozen_string_literal true

require 'rails_helper'

RSpec.describe 'JobSerializer' do

  let(:work_plan) { create(:work_plan, project_id: 1) }
  let(:process_modules) { create_list(:aker_process_module, 3) }
  let(:work_order) { create(:work_order, process_modules: process_modules, work_plan: work_plan)}
  let(:job) { create(:job, work_order: work_order) }
  let(:set) { double("SetClientSet", uuid: SecureRandom.uuid) }
  let(:job_serializer) { JobSerializer.new }

  describe 'serialize' do

    before do
      stub_request(:get, "http://external-server:3300/api/v1/nodes/1")
        .to_return(status: 200, body: file_fixture("project.json"), headers: { 'Content-Type' => 'application/vnd.api+json' })

      stub_request(:get, "http://external-server:3000/api/v1/sets/#{set.uuid}?include=materials")
        .to_return(status: 200, body: file_fixture("set_with_materials.json"), headers: { 'Content-Type' => 'application/vnd.api+json' })

      stub_request(:post, "http://external-server:5000/materials/search")
        .with(
          body: "{\"where\":{\"_id\":{\"$in\":[\"01cb5442-f7f1-4247-813e-8e7693b0b17d\",\"030a06d1-0309-4fb0-8c7f-571d5c8dcebc\",\"056ee9c0-0a9d-4213-bb68-0aacbc53653b\",\"06816dc3-f68e-4491-9b24-36a00e79133e\",\"082828d2-9635-4b7d-ba4c-46bddcb6692c\"]}}}",
        )
        .to_return(status: 200, body: file_fixture("materials.json"), headers: { 'Content-Type' => 'application/json' })

      stub_request(:get, "http://external-server:5000/materials/json_schema")
        .to_return(status: 200, body: file_fixture("material_schema.json"), headers: { 'Content-Type' => 'application/json' })

      stub_request(:post, "http://external-server:5000/containers/search")
        .with(
          body: "{\"where\":{\"slots.material\":{\"$in\":[\"01cb5442-f7f1-4247-813e-8e7693b0b17d\",\"030a06d1-0309-4fb0-8c7f-571d5c8dcebc\",\"056ee9c0-0a9d-4213-bb68-0aacbc53653b\",\"06816dc3-f68e-4491-9b24-36a00e79133e\",\"082828d2-9635-4b7d-ba4c-46bddcb6692c\"]}}}",
        )
        .to_return(status: 200, body: file_fixture("containers.json"), headers: { 'Content-Type' => 'application/json' })

      stub_request(:get, "http://external-server:5000/containers/json_schema")
        .to_return(status: 200, body: file_fixture("container_schema.json").read, headers: { 'Content-Type' => 'application/vnd.api+json' })

      dj = job.decorate
      dj.input_set = set
      @serialized_job = job_serializer.serialize(dj)
    end

    describe 'type' do
      it 'is "jobs"' do
        expect(@serialized_job[:type]).to eql('jobs')
      end
    end

    describe 'id' do
      it 'is the job id' do
        expect(@serialized_job[:id]).to eql(job.id)
      end
    end

    describe 'attributes' do

      before do
        @attributes = @serialized_job[:attributes]
      end

      it 'is a Hash' do
        expect(@attributes).to be_kind_of Hash
      end

      describe 'job_id' do
        it 'is the job id' do
          expect(@attributes[:job_id]).to eql(job.id)
        end
      end

      describe 'job_uuid' do
        it 'is the job uuid' do
          expect(@attributes[:job_uuid]).to eql(job.uuid)
        end
      end

      describe 'work_order_id' do
        it 'is the work order id' do
          expect(@attributes[:work_order_id]).to eql(work_order.id)
        end
      end

      describe 'aker_job_url' do
        it 'is the api URL for a job' do
          expect(@attributes[:aker_job_url]).to include("/api/v1/jobs/#{job.id}")
        end
      end

      describe 'process_name' do
        it 'is the name of the process' do
          expect(@attributes[:process_name]).to eql(work_order.process.name)
        end
      end

      describe 'process_uuid' do
        it 'is UUID of the process' do
          expect(@attributes[:process_uuid]).to eql(work_order.process.uuid)
        end
      end

      describe 'modules' do
        it 'is a list of Module names' do
          expect(@attributes[:modules]).to eql(process_modules.pluck(:name))
        end
      end

      describe 'comment' do
        it 'is the Work Plan comment' do
          expect(@attributes[:comment]).to eql(work_plan.comment)
        end
      end

      describe 'priority' do
        it 'is the Work Plan priority' do
          expect(@attributes[:priority]).to eql(work_plan.priority)
        end
      end

      describe 'project_uuid' do
        it 'is the Work Plan project uuid' do
          expect(@attributes[:project_uuid]).to eql('4e05ab57-2548-4479-a76a-59d45b47637c')
        end
      end

      describe 'project_name' do
        it 'is the Work Plan project name' do
          expect(@attributes[:project_name]).to eql('Institute Research QQ 2017-2021')
        end
      end

      describe 'data_release_uuid' do
        it 'is the Work Plan data_release_strategy_id' do
          expect(@attributes[:data_release_uuid]).to eql(work_plan.data_release_strategy_id)
        end
      end

      describe 'cost_code' do
        it 'is the Work Plan project cost code' do
          expect(@attributes[:cost_code]).to eql("S1234-1")
        end
      end

      describe 'materials' do
        it 'is an Array' do
          expect(@attributes[:materials]).to be_kind_of Array
        end

        it 'serializes each Material' do
          expect(@attributes[:materials][0]).to eql(
            {
              _id: "01cb5442-f7f1-4247-813e-8e7693b0b17d",
              is_tumour: "normal",
              supplier_name: "rjl2018080814",
              taxon_id: "9606",
              tissue_type: "DNA",
              gender: "male",
              donor_id: "3",
              phenotype: "6",
              scientific_name: "Homo sapiens",
              available: true,
              address: "H:2"
            }
          )
          expect(@attributes[:materials][1]).to eql(
            {
              _id: "030a06d1-0309-4fb0-8c7f-571d5c8dcebc",
              is_tumour: "normal",
              supplier_name: "rjl2018080833",
              taxon_id: "9606",
              tissue_type: "DNA",
              gender: "female",
              donor_id: "3",
              phenotype: "6",
              scientific_name: "Homo sapiens",
              available: true,
              address: "C:5"
            }
          )
          expect(@attributes[:materials][2]).to eql(
            {
              _id: "056ee9c0-0a9d-4213-bb68-0aacbc53653b",
              is_tumour: "normal",
              supplier_name: "rjl2018080813",
              taxon_id: "9606",
              tissue_type: "DNA",
              gender: "male",
              donor_id: "3",
              phenotype: "6",
              scientific_name: "Homo sapiens",
              available: true,
              address: "G:2"
            }
          )
          expect(@attributes[:materials][3]).to eql(
            {
              _id: "06816dc3-f68e-4491-9b24-36a00e79133e",
              is_tumour: "normal",
              supplier_name: "rjl2018080815",
              taxon_id: "9606",
              tissue_type: "DNA",
              gender: "male",
              donor_id: "3",
              phenotype: "6",
              scientific_name: "Homo sapiens",
              available: true,
              address: "A:3"
            }
          )
          expect(@attributes[:materials][4]).to eql(
            {
              _id: "082828d2-9635-4b7d-ba4c-46bddcb6692c",
              is_tumour: "normal",
              supplier_name: "rjl2018080886",
              taxon_id: "9606",
              tissue_type: "DNA",
              gender: "male",
              donor_id: "3",
              phenotype: "6",
              scientific_name: "Homo sapiens",
              available: true,
              address: "H:11"
            }
          )
        end
      end

      # It's being assumed that there is only one Container for a Job
      # I imagine this will have to change at some point
      describe 'container' do

        it 'is a Hash' do
          expect(@attributes[:container]).to be_kind_of Hash
        end

        describe 'container_id' do
          it 'is the Container ID' do
            expect(@attributes[:container][:container_id]).to eql("81ed8fa3-6bcd-484d-ace8-e5aaf83b7d4c")
          end
        end

        describe 'barcode' do
          it 'is the Container barcode' do
            expect(@attributes[:container][:barcode]).to eql("AKER-717")
          end
        end

        describe 'num_of_rows' do
          it 'is the Container num_of_rows' do
            expect(@attributes[:container][:num_of_rows]).to eql(8)
          end
        end

        describe 'num_of_cols' do
          it 'is the Container num_of_cols' do
            expect(@attributes[:container][:num_of_cols]).to eql(12)
          end
        end

      end

    end
  end

end