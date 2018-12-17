# frozen_string_literal: true

require 'rails_helper'
require 'support/test_services_helper'

RSpec.describe 'EventMessage' do
  include TestServicesHelper

  describe 'WorkOrderEventMessage' do
    describe '#initialize' do
      it 'is initalized with a param object' do
        w = build(:work_order)
        message = WorkOrderEventMessage.new(work_order: w, status: 'complete')
        expect(message.work_order).to eql(w.decorate)
        expect(message.instance_variable_get(:@status)).to eq('complete')
      end
    end

    describe '#generate_json' do

      let(:set) { double(:set, uuid: 'set_uuid', id: 'set_uuid', meta: { 'size' => '4' }) }
      let(:project) { double(:project, id: 123, name: 'test project', node_uuid: '12345a') }
      let(:product) { build(:product, name: 'test product') }
      let(:process) { build(:process, name: 'test process') }
      let(:first_comment) { 'first comment' }
      let(:expected_work_order_role) do
        {
          'role_type' => 'work_order',
          'subject_type' => 'work_order',
          'subject_friendly_name' => work_order.name,
          'subject_uuid' => work_order.work_order_uuid
        }
      end
      let(:expected_project_role) do
        {
          'role_type' => 'project',
          'subject_type' => 'project',
          'subject_friendly_name' => project.name,
          'subject_uuid' => project.node_uuid
        }
      end
      let(:expected_product_role) do
        {
          'role_type' => 'product',
          'subject_type' => 'product',
          'subject_friendly_name' => product.name,
          'subject_uuid' => product.uuid,
        }
      end
      let(:expected_process_role) do
        {
          'role_type' => 'process',
          'subject_type' => 'process',
          'subject_friendly_name' => process.name,
          'subject_uuid' => process.uuid,
        }
      end
      let(:expected_work_plan_role) do
        {
          'role_type' => 'work_plan',
          'subject_type' => 'work_plan',
          'subject_friendly_name' => plan.name,
          'subject_uuid' => plan.uuid,
        }
      end

      let(:drs) { create(:data_release_strategy) }

      let(:plan) do
        pl = create(:work_plan, product: product, project_id: project.id, comment: first_comment, data_release_strategy: drs)
        allow_any_instance_of(WorkPlanDecorator).to receive(:project).and_return(project)
        allow(pl).to receive(:data_release_strategy).and_return(drs)
        pl
      end

      let(:cancelled_job) { create(:cancelled_job) }
      let(:completed_job) { create(:completed_job) }

      let(:work_order) do
        wo = create(:work_order, status: WorkOrder.ACTIVE, work_plan: plan, process: process, jobs: [cancelled_job, completed_job])
        allow(wo).to receive(:work_plan).and_return plan
        allow(wo).to receive(:id).and_return 123
        allow(wo).to receive(:total_cost).and_return 50
        allow_any_instance_of(WorkOrderDecorator).to receive(:set).and_return set
        wo
      end

      let(:message) do
        Timecop.freeze do
          m = WorkOrderEventMessage.new(work_order: work_order, status: status)
          @timestamp = Time.now.utc.iso8601
          m
        end
      end

      let(:json) { JSON.parse(message.generate_json) }

      let(:roles) { json['roles'] }
      let(:metadata) { json['metadata'] }

      shared_examples_for 'work order event message json' do
        it 'should have the correct event type' do
          expect(json['event_type']).to eq("aker.events.work_order.#{status}")
        end

        it 'should have the correct lims id' do
          expect(json['lims_id']).to eq('aker')
        end

        it 'should have the correct uuid' do
          expect(json['uuid']).to be_a_uuid
        end

        it 'should have the correct user identifier' do
          expect(json['user_identifier']).to eq(plan.owner_email)
        end

        it 'should have the correct timestamp' do
          expect(json['timestamp']).to eq(@timestamp)
        end

        # Roles
        it 'should have the correct number of roles' do
          expect(roles.length).to eq(5)
        end
        it 'should include the product role' do
          expect(roles).to include(expected_product_role)
        end
        it 'should include the project role' do
          expect(roles).to include(expected_project_role)
        end
        it 'should include the work order role' do
          expect(roles).to include(expected_work_order_role)
        end
        it 'should include the process role' do
          expect(roles).to include(expected_process_role)
        end
        it 'should include the work plan role' do
          expect(roles).to include(expected_work_plan_role)
        end

        it 'should produce the same JSON consistently' do
          expect(message.generate_json).to eq(message.generate_json)
        end
      end

      context 'when work order is dispatched' do
        let(:status) { 'dispatched' }

        it_behaves_like 'work order event message json'

        context 'when there is no set defined for the work order' do
          it 'generates the message without raising an exception' do
            allow_any_instance_of(WorkOrderDecorator).to receive(:set_size).and_return nil
            expect(metadata['num_materials']).to eq(0)
          end
        end

        # Metadata
        it 'should have the correct amount of metadata' do
          expect(metadata.length).to eq(4)
        end
        it 'should have the correct work order id' do
          expect(metadata['work_order_id']).to eq(work_order.id)
        end
        it 'should have the correct quoted price' do
          expect(metadata['quoted_price']).to eq(work_order.total_cost)
        end
        it 'should have the correct num materials' do
          expect(metadata['num_materials']).to eq(set.meta['size'])
        end
        it 'should have the correct data release strategy uuid' do
          expect(metadata['data_release_strategy_uuid']).to eq(work_order.work_plan.data_release_strategy_id)
        end

      end

      context 'when work order is concluded' do
        let(:status) { 'completed' }

        it_behaves_like 'work order event message json'

        # Metadata
        it 'should have the correct work order id' do
          expect(metadata['work_order_id']).to eq(work_order.id)
        end

        it 'should have the correct amount of metadata' do
          expect(metadata.length).to eq(3)
        end

        it 'should have the correct num of completed jobs' do
          expect(metadata['num_completed_jobs']).to eq(1)
        end
        it 'should have the corrent num of cancelled jobs' do
          expect(metadata['num_cancelled_jobs']).to eq(1)
        end
      end
    end
  end

  describe 'CatalogueEventMessage' do
    let(:catalogue_data) do
      {
        lims_id: 'my_lims',
        pipeline: 'my_pipeline',
      }
    end

    let(:message) do
      Timecop.freeze do
        m = CatalogueEventMessage.new(catalogue: catalogue_data, error: error)
        @timestamp = Time.now.utc.iso8601
        m
      end
    end

    describe '#generate_json' do
      let(:json) { JSON.parse(message.generate_json) }

      shared_examples_for 'catalogue event message json' do
        it 'should generate the same json consistenly' do
          expect(message.generate_json).to eq(message.generate_json)
        end

        it 'should contain the timestamp' do
          expect(json['timestamp']).to eq(@timestamp)
        end

        it 'should contain the uuid' do
          expect(json['uuid']).to be_a_uuid
        end

        it 'should have an empty array of roles' do
          expect(json['roles']).to be_empty
        end

        it 'should have the correct lims id' do
          expect(json['lims_id']).to eq(catalogue_data[:lims_id])
        end

        it 'should have the correct user identifier' do
          expect(json['user_identifier']).to eq(catalogue_data[:lims_id])
        end

        it 'should have the correct metadata' do
          expect(json['metadata']).to eq expected_metadata
        end
        it 'should have the correct event type' do
          expect(json['event_type']).to eq expected_event_type
        end
      end

      context 'when there is an error' do
        let(:error) { 'everything is broken' }
        let(:expected_metadata) { { 'error' => error } }
        let(:expected_event_type) { 'aker.events.catalogue.rejected' }

        it_behaves_like 'catalogue event message json'
      end

      context 'when there is no error' do
        let(:error) { nil }
        let(:expected_metadata) { { 'pipeline' => catalogue_data[:pipeline] } }
        let(:expected_event_type) { 'aker.events.catalogue.accepted' }

        it_behaves_like 'catalogue event message json'
      end
    end
  end

end
