# frozen_string_literal: true

require 'rails_helper'
require 'support/test_services_helper'

RSpec.describe 'EventMessage' do
  include TestServicesHelper

  let(:set) { double(:set, uuid: 'set_uuid', id: 'set_uuid', meta: { 'size' => '4' }) }
  let(:project) { double(:project, id: 123, name: 'test project', node_uuid: '12345a', program: [program]) }
  let(:program) { double(:project, id: 5, name: 'Program Alpha', node_uuid: SecureRandom.uuid) }
  let(:product) { build(:product, name: 'test product') }
  let(:process) { build(:process, name: 'test process') }
  let(:drs) { create(:data_release_strategy) }
  let(:owner_email) { 'user@sanger.ac.uk' }

  let(:plan) do
    pl = create(:work_plan, product: product, owner_email: owner_email, project_id: project.id, comment: 'first comment', data_release_strategy: drs)
    allow_any_instance_of(WorkPlanDecorator).to receive(:project).and_return(project)
    allow(pl).to receive(:data_release_strategy).and_return(drs)
    pl
  end

  let(:work_order) do
    wo = create(:work_order, status: WorkOrder.ACTIVE, work_plan: plan, process: process)
    create(:cancelled_job, work_order: wo)
    create(:completed_job, work_order: wo)
    wo.jobs.reload
    allow(wo).to receive(:work_plan).and_return plan
    allow(wo).to receive(:total_cost).and_return 50
    allow_any_instance_of(WorkOrderDecorator).to receive(:set).and_return set
    wo
  end

  let(:cancelled_job) { work_order.jobs.first }
  let(:completed_job) { work_order.jobs.second }

  let(:json) { JSON.parse(message.generate_json) }

  let(:roles) { json['roles'] }
  let(:metadata) { json['metadata'] }

  let(:expected_work_order_role) { role('work_order', work_order.name, work_order.work_order_uuid) }
  let(:expected_project_role) { role('project', project.name, project.node_uuid) }
  let(:expected_product_role) { role('product', product.name, product.uuid) }
  let(:expected_process_role) { role('process', process.name, process.uuid) }
  let(:expected_work_plan_role) { role('work_plan', plan.name, plan.uuid) }

  def role(role_type, name, uuid)
    {
      'role_type' => role_type,
      'subject_type' => role_type,
      'subject_friendly_name' => name,
      'subject_uuid' => uuid,
    }
  end

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

      let(:forwarded_jobs) { nil }
      let(:dispatched_jobs) { nil }

      let(:message) do
        Timecop.freeze do
          m = WorkOrderEventMessage.new(work_order: work_order, status: status,
              forwarded_jobs: forwarded_jobs, dispatched_jobs: dispatched_jobs)
          @timestamp = Time.now.utc.iso8601
          m
        end
      end

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
          expect(json['user_identifier']).to eq(owner_email)
        end

        it 'should have the correct timestamp' do
          expect(json['timestamp']).to eq(@timestamp)
        end

        # Roles
        it 'should have the correct number of roles' do
          expect(roles.length).to eq(6 + (forwarded_jobs&.size || 0) + (dispatched_jobs&.size || 0))
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
        it 'should include the program role' do
          prog_role = role('program', program.name, program.node_uuid)
          prog_role['subject_type'] = 'project'
          expect(roles).to include prog_role
        end

        it 'should produce the same JSON consistently' do
          expect(message.generate_json).to eq(message.generate_json)
        end
      end

      context 'when work order is dispatched' do
        let(:forwarded_jobs) { (0...3).map { create(:job) } }
        let(:dispatched_jobs) { work_order.jobs }
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

        it 'should include roles for the forwarded jobs' do
          forwarded_jobs.each do |job|
            expect(roles).to include job_role(job, 'forwarded_job')
          end
        end
        it 'should include roles for the dispatched jobs' do
          dispatched_jobs.each do |job|
            expect(roles).to include job_role(job, 'dispatched_job')
          end
        end

        def job_role(job, roletype)
          {
            'subject_uuid' => job.uuid,
            'subject_friendly_name' => job.name,
            'role_type' => roletype,
            'subject_type' => 'job',
          }
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
        it 'should generate the same json consistenlty' do
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

  describe 'JobEventMessage' do
    let(:job) { completed_job }
    let(:status) { 'completed' }

    let(:message) do
      Timecop.freeze do
        msg = JobEventMessage.new(job: job, status: status)
        @timestamp = Time.now.utc.iso8601
        msg
      end
    end

    describe '#generate_json' do
      it 'should have the correct fields' do
        expect(json['timestamp']).to eq(@timestamp)
        expect(json['event_type']).to eq('aker.events.job.' + status)
        expect(json['lims_id']).to eq('aker')
        expect(json['user_identifier']).to eq(owner_email)
        expect(json['uuid']).to be_a_uuid
        expect(json['roles']).to be_present
        expect(json['metadata']).to be_present
      end

      it 'should produce the same JSON consistently' do
        expect(message.generate_json).to eq(message.generate_json)
      end

      it 'should have the correct metadata' do
        expect(metadata.size).to eq(2)
        expect(metadata['work_order_id']).to eq(work_order.id)
        expect(metadata['work_plan_id']).to eq(plan.id)
      end

      it 'should have the correct roles' do
        expect(roles.size).to eq(6)
        expect(roles).to include expected_work_order_role
        expect(roles).to include expected_product_role
        expect(roles).to include expected_product_role
        expect(roles).to include expected_process_role
        expect(roles).to include expected_work_plan_role
        expect(roles).to include role('job', job.name, job.uuid)
      end
    end
  end

end
