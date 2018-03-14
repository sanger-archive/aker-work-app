# frozen_string_literal: true

require 'rails_helper'
require 'support/test_services_helper'

RSpec.describe 'EventMessage' do
  include TestServicesHelper

  context 'WorkOrderEventMessage' do
    describe '#initialize' do
      it 'is initalized with a param object' do
        w = double('work_order')
        message = WorkOrderEventMessage.new(work_order: w, status: 'complete')
        expect(message.work_order).to be w
        expect(message.instance_variable_get(:@status)).to eq('complete')
      end
    end

    describe '#generate_json' do
      before do
        allow(SecureRandom).to receive(:uuid).and_return(fake_uuid)
      end

      let(:set) { double(:set, uuid: 'set_uuid', id: 'set_uuid', meta: { 'size' => '4' }) }
      let(:finished_set) do
        double(
          :set,
          uuid: 'finished_set_uuid',
          id: 'finished_set_uuid',
          meta: { 'size' => '2' }
        )
      end
      let(:project) { double(:project, id: 123, name: 'test project', node_uuid: '12345a') }
      let(:product) { build(:product, name: 'test product') }
      let(:process) { build(:process, name: 'test process') }
      let(:fake_uuid) { 'my_fake_uuid' }
      let(:fake_trace) { 'my_trace_id' }
      let(:first_comment) { 'first comment' }
      let(:second_comment) { 'second comment' }
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

      let(:plan) do
        pl = build(:work_plan, product: product, project_id: project.id, comment: first_comment, desired_date: Time.zone.today + 5)
        allow(pl).to receive(:project).and_return(project)
        pl
      end

      let(:work_order) do
        wo = build(:work_order, status: WorkOrder.ACTIVE, work_plan: plan, process: process)
        allow(wo).to receive(:id).and_return 123
        allow(wo).to receive(:close_comment).and_return second_comment
        allow(wo).to receive(:total_cost).and_return 50
        allow(wo).to receive(:set).and_return set
        allow(wo).to receive(:finished_set).and_return finished_set
        wo
      end

      let(:message) do
        m = WorkOrderEventMessage.new(work_order: work_order, status: status)
        allow(m).to receive(:trace_id).and_return fake_trace
        m
      end

      let(:json) do
        Timecop.freeze do
          json_data = JSON.parse(message.generate_json)
          @timestamp = Time.now.utc.iso8601
          json_data
        end
      end

      let(:roles) { json['roles'] }
      let(:metadata) { json['metadata'] }

      shared_examples_for 'event message json' do
        it 'should have the correct event type' do
          expect(json['event_type']).to eq("aker.events.work_order.#{status}")
        end

        it 'should have the correct lims id' do
          expect(json['lims_id']).to eq('aker')
        end

        it 'should have the correct uuid' do
          expect(json['uuid']).to eq(fake_uuid)
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
      end

      context 'when work order is submitted' do
        let(:status) { 'submitted' }

        it_behaves_like 'event message json'

        context 'when there is no set defined for the work order' do
          it 'generates the message without raising an exception' do
            allow(work_order).to receive(:set).and_return nil
            expect(metadata['num_materials']).to eq(0)
          end
        end

        # Metadata
        it 'should have the correct amount of metadata' do
          expect(metadata.length).to eq(5)
        end
        it 'should have the correct work order id' do
          expect(metadata['work_order_id']).to eq(work_order.id)
        end

        it 'should have the correct comment' do
          expect(metadata['comment']).to eq(first_comment)
        end
        it 'should have the correct quoted price' do
          expect(metadata['quoted_price']).to eq(work_order.total_cost)
        end
        it 'should have the correct trace id' do
          expect(metadata['zipkin_trace_id']).to eq(fake_trace)
        end
        it 'should have the correct num materials' do
          expect(metadata['num_materials']).to eq(set.meta['size'])
        end
      end

      context 'when work order is completed' do
        let(:status) { 'completed' }

        it_behaves_like 'event message json'

        context 'when there is no finished set as a result of the work order' do
          it 'generates the message without raising an exception' do
            allow(work_order).to receive(:finished_set).and_return nil
            expect(metadata['num_new_materials']).to eq(0)
          end
        end

        # Metadata
        it 'should have the correct work order id' do
          expect(metadata['work_order_id']).to eq(work_order.id)
        end

        it 'should have the correct amount of metadata' do
          expect(metadata.length).to eq(4)
        end
        it 'should have the correct comment' do
          expect(metadata['comment']).to eq(second_comment)
        end
        it 'should have the correct trace id' do
          expect(metadata['zipkin_trace_id']).to eq(fake_trace)
        end
        it 'should have the correct num new materials' do
          expect(metadata['num_new_materials']).to eq(finished_set.meta['size'])
        end
      end
    end
  end
end
