require 'rails_helper'

RSpec.describe UpdatePlanService do
  let(:plan) { create(:work_plan) }
  let(:messages) { {} }
  let(:dispatch) { false }
  let(:params) { }
  let(:user_and_groups) { ['user@here', 'all'] }
  let(:service) { UpdatePlanService.new(params, plan, dispatch, user_and_groups, messages) }
  let(:catalogue) { create(:catalogue, lims_id: 'SQSC' ) }
  let(:product) { create(:product, catalogue: catalogue) }
  let(:project) { make_project(18, 'S1234-0') }
  let(:set) { make_set(false, true, locked_set) }
  let(:locked_set) { make_set(false, true) }
  let(:processes) { create_processes(product) }
  let(:drs) { create(:data_release_strategy) }

  before(:each) do
    stub_billing_facade
    extra_stubbing
    stub_data_release_strategy
    @result = service.perform
  end

  def extra_stubbing
  end

  def stub_data_release_strategy
    allow(DataReleaseStrategyClient).to receive(:find_strategies_by_user).and_return([drs])
  end

  def stub_billing_facade
    allow(BillingFacadeClient).to receive(:validate_cost_code?).and_return(true)
  end

  def stub_project
    allow(StudyClient::Node).to receive(:authorize!)
  end

  def stub_stamps
    allow(StampClient::Permission).to receive(:check_catch).and_return true
  end

  def make_rs_response(items)
    result_set = double(:result_set, to_a: items.to_a, has_next?: false)
    return double(:response, result_set: result_set)
  end

  def make_project(id, cost_code)
    proj = double(:project, id: id, name: "project #{id}", cost_code: cost_code)
    allow(StudyClient::Node).to receive(:find).with(id).and_return([proj])
    proj
  end

  def make_set(empty=false, available=true, clone_set=nil)
    uuid = SecureRandom.uuid
    set = double(:set, id: uuid, uuid: uuid, name: "Set #{uuid}", locked: clone_set.nil?)

    if empty
      matids = []
      set_materials = double(:set_materials, materials: [])
    else
      matid = SecureRandom.uuid
      matids = [matid]
      set_content_material = double(:material, id: matid)
      set_materials = double(:set_materials, materials: [set_content_material])
      material = double(:material, id: matid, attributes: { 'available' => available})
      allow(MatconClient::Material).to receive(:where).with("_id" => { "$in" => [matid]}).and_return(make_rs_response([material]))
    end

    allow(SetClient::Set).to receive(:find_with_materials).with(uuid).and_return([set_materials])
    if clone_set
      allow(set).to receive(:create_locked_clone).and_return(clone_set)
    end
    allow(SetClient::Set).to receive(:find).with(uuid).and_return([set])
    allow(set).to receive(:_material_uuids).and_return(matids)
    set
  end

  def make_plan_with_orders
    plan = create(:work_plan, original_set_uuid: set.uuid, project_id: project.id, product: product, data_release_strategy_id: drs.id)
    module_choices = processes.map { |pro| [pro.process_modules.first.id] }
    product_options_selected_values = module_choices.map{|c| [nil]}
    wo = plan.create_orders(module_choices, set.id, product_options_selected_values)
    plan.reload
  end

  # Creates two processes for a product. Each process has two modules: one default and one not default.
  def create_processes(prod)
    (0..1).map do |i|
      pro = create(:process, name: "process #{prod.id}-#{i}")
      create(:aker_product_process, product: product, aker_process: pro, stage: i)
      mod = create(:aker_process_module, name: "module #{prod.id}-#{i}", aker_process_id: pro.id)
      create(:aker_process_module_pairings, to_step_id: mod.id, default_path: true, aker_process: pro)
      create(:aker_process_module_pairings, from_step_id: mod.id, default_path: true, aker_process: pro)
      modb = create(:aker_process_module, name: "module #{prod.id}-#{i}B", aker_process_id: pro.id)
      create(:aker_process_module_pairings, to_step_id: modb.id, default_path: false, aker_process: pro)
      create(:aker_process_module_pairings, from_step_id: modb.id, default_path: false, aker_process: pro)
      pro
    end
  end

  def stub_broker_connection
    stub_const('BrokerHandle', class_double('BrokerHandle', working?: true))
    allow(BrokerHandle).to receive(:publish)
  end

  describe 'selecting a project' do

    def extra_stubbing
      stub_project
    end

    let(:new_project) { make_project(21, 'S1234-2') }

    let(:params) { { project_id: new_project.id } }

    context 'when the plan has no set selected' do
      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /select.*set/
      end
      it 'should not set the project in the plan' do
        expect(plan.project_id).to be_nil
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
    end

    context 'when the plan has a set selected' do
      let(:plan) { create(:work_plan, original_set_uuid: set.uuid) }

      it { expect(@result).to be_truthy }
      it 'should produce no error messages' do
        expect(messages).to be_empty
      end
      it 'should set the project in the plan' do
        expect(plan.project_id).to eq(new_project.id)
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
    end

    context 'when the plan already has a project selected' do
      let(:plan) { create(:work_plan, original_set_uuid: set.uuid, project_id: project.id) }
      it { expect(@result).to be_truthy }
      it 'should produce no error messages' do
        expect(messages).to be_empty
      end
      it 'should set the project in the plan' do
        expect(plan.project_id).to eq(new_project.id)
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
    end

    context 'when the cost code is invalid' do
      let(:plan) { create(:work_plan, original_set_uuid: set.uuid) }
      def stub_billing_facade
        allow(BillingFacadeClient).to receive(:validate_cost_code?).and_return(false)
      end
      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /cost code/
      end
      it 'should not set the project in the plan' do
        expect(plan.project_id).to be_nil
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
    end

    context 'when the project cannot be authorised' do
      let(:plan) { create(:work_plan, original_set_uuid: set.uuid) }
      def stub_project
        ex = AkerPermissionGem::NotAuthorized.new("Not authorised")
        allow(StudyClient::Node).to receive(:authorize!).with(:spend, new_project.id, user_and_groups).and_raise ex
      end

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /not authori[zs]ed/i
      end
      it 'should have tried to authorise the project' do
        expect(StudyClient::Node).to have_received(:authorize!).with(:spend, new_project.id, user_and_groups)
      end
      it 'should not set the project in the plan' do
        expect(plan.project_id).to be_nil
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
    end

    context 'when the project has no cost code' do
      let(:new_project) { make_project(21, nil) }
      let(:plan) { create(:work_plan, original_set_uuid: set.uuid) }

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /cost code/
      end
      it 'should not set the project in the plan' do
        expect(plan.project_id).to be_nil
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
    end

    context 'when the project does not exist' do
      let(:params) do
        id = -100
        allow(StudyClient::Node).to receive(:find).with(id).and_return([])
        { project_id: id }
      end
      let(:plan) { create(:work_plan, original_set_uuid: set.uuid) }

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /project.*found/
      end
      it 'should not set the project in the plan' do
        expect(plan.project_id).to be_nil
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
    end

    context 'when the plan is in progress' do
      let(:plan) do
        plan = make_plan_with_orders
        plan.work_orders.first.update_attributes!(status: 'active')
        plan
      end

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /in progress/
      end
      it 'should not change the project in the plan' do
        expect(plan.project_id).to eq(project.id)
      end
      it 'should still be active' do
        expect(plan).to be_active
      end
    end

  end

  describe 'selecting a set' do
    let(:available) { true }
    let(:empty) { false }
    let(:new_set) { make_set(empty, available) }
    let(:params) { { original_set_uuid: new_set.uuid } }

    def extra_stubbing
      stub_stamps
    end

    context 'when the plan has no set selected' do
      it { expect(@result).to be_truthy }
      it 'should produce no error messages' do
        expect(messages).to be_empty
      end
      it 'should set the set in the plan' do
        expect(plan.original_set_uuid).to eq(new_set.uuid)
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
    end

    context 'when the plan is already active' do
      let(:plan) do
        plan = make_plan_with_orders
        plan.work_orders.first.update_attributes!(status: 'active')
        plan
      end

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /in progress/i
      end
      it 'should not change the set in the plan' do
        expect(plan.original_set_uuid).to eq(set.uuid)
      end
      it 'should still be active' do
        expect(plan).to be_active
      end
    end

    context 'when the materials are not available' do
      let(:available) { false }

      it { expect(@result).to be_falsey }
      it 'should produce an error messages' do
        expect(messages[:error]).to match /available/i
      end
      it 'should not change the set in the plan' do
        expect(plan.original_set_uuid).to be_nil
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
    end

    context 'when the set is empty' do
      let(:empty) { true }

      it { expect(@result).to be_falsey }
      it 'should produce an error messages' do
        expect(messages[:error]).to match /empty/i
      end
      it 'should not change the set in the plan' do
        expect(plan.original_set_uuid).to be_nil
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
    end

    context 'when user does not have consume permission' do
      def stub_stamps
        allow(StampClient::Permission).to receive(:check_catch).and_return false
        allow(StampClient::Permission).to receive(:unpermitted_uuids).and_return([new_set._material_uuids.first])
      end

      it { expect(@result).to be_falsey }
      it 'should produce an error messages' do
        expect(messages[:error]).to match /not authori[sz]ed/i
      end
      it 'should not change the set in the plan' do
        expect(plan.original_set_uuid).to be_nil
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
    end
  end

  describe 'selecting a product' do
    let(:product_options) { processes.map { |pro| [pro.process_modules.first.id] } }
    let(:params) do
      {
        product_id: product.id,
        product_options: product_options.to_json,
      }
    end

    let(:module_cost) { 15 }

    def stub_billing_facade
      super
      allow(BillingFacadeClient).to receive(:get_cost_information_for_module).and_return(module_cost)
    end

    context 'when the plan does not have a project yet' do
      let(:plan) { create(:work_plan, original_set_uuid: set.uuid) }

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /select.*project/
      end
      it 'should not change the product in the plan' do
        expect(plan.product_id).to be_nil
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
      it 'should not have orders' do
        expect(plan.work_orders).to be_empty
      end
    end

    context 'when the plan has a project' do
      let(:plan) { create(:work_plan, original_set_uuid: set.uuid, project_id: project.id) }

      it { expect(@result).to be_truthy }
      it 'should not produce an error message' do
        expect(messages).to be_empty
      end
      it 'should set the product in the plan' do
        expect(plan.product_id).to eq(product.id)
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
      it 'should have created orders' do
        expect(plan.work_orders.length).to eq(processes.length)
      end
      it 'should have correctly set up work orders' do
        plan.work_orders.zip(processes, product_options).each do |order, pro, opts|
          expect(order).to be_queued
          expect(order.process).to eq(pro)
          expect(order.work_order_module_choices.map(&:aker_process_modules_id)).to eq(opts)
        end
      end
      it 'orders should have correct sets' do
        plan.work_orders.each_with_index do |order, i|
          expect(order.original_set_uuid).to eq(i==0 ? plan.original_set_uuid : nil)
          expect(order.set_uuid).to be_nil
        end
      end
    end

    context 'when there are not modules given for each process' do
      let(:plan) { create(:work_plan, original_set_uuid: set.uuid, project_id: project.id) }
      let(:product_options) { [[processes[0].process_modules.first.id]] }

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /modules/
      end
      it 'should not set the product in the plan' do
        expect(plan.product_id).to be_nil
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
      it 'should not have created orders' do
        expect(plan.work_orders).to be_empty
      end
    end

    context 'when there is a selected value' do
      def work_order_module
        processes.map(&:process_modules).flatten.reduce({}) do |memo, mod|
          mod.update_attributes(min_value:1, max_value: 5)
          memo[mod.id.to_s] = {
            selected_value: selected_value
          }
          memo
        end
      end
      let(:plan) { create(:work_plan, original_set_uuid: set.uuid, project_id: project.id) }
      let(:params) do
        {
          product_id: product.id,
          product_options: product_options.to_json,
          work_order_module: work_order_module
        }
      end
      context 'when the module selected values are not valid' do
        let(:selected_value) { 7 }
        it { expect(@result).to be_falsey }
        it 'should produce an error message' do
          expect(messages[:error]).to match Regexp.new('Creating.*failed.*')
        end
      end
      context 'when the module selected values are valid' do
        let(:selected_value) { 3 }
        it { expect(@result).to be_truthy }
      end

    end
    context 'when the module ids are not a valid path for a process' do
      let(:plan) { create(:work_plan, original_set_uuid: set.uuid, project_id: project.id) }
      let(:product_options) do
        pops = processes.map { |pro| [pro.process_modules.first.id] }
        pops[1] += pops[1]
        pops
      end

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match Regexp.new('modules.*valid.*'+Regexp.escape(processes[1].name))
      end
      it 'should not set the product in the plan' do
        expect(plan.product_id).to be_nil
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
      it 'should not have created orders' do
        expect(plan.work_orders).to be_empty
      end
    end

    context 'when the modules and cost code are invalid' do
      let(:plan) { create(:work_plan, original_set_uuid: set.uuid, project_id: project.id) }
      let(:module_cost) { nil }

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /modules.*cost code/
      end
      it 'should not set the product in the plan' do
        expect(plan.product_id).to be_nil
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
      it 'should not have created orders' do
        expect(plan.work_orders).to be_empty
      end
    end

    context 'when the work orders are already created but not started' do
      let(:old_locked_set) { make_set(false, true) }

      let(:plan) do
        plan = make_plan_with_orders
        @old_order = plan.work_orders.first
        @old_order.update_attributes!(set_uuid: old_locked_set.uuid)
        plan
      end

      # product options different from the defaults
      let(:product_options) do
        processes.map { |pro| [pro.process_modules[1].id] }
      end

      it { expect(@result).to be_truthy }
      it 'should not produce an error message' do
        expect(messages).to be_empty
      end
      it 'should set the product in the plan' do
        expect(plan.product_id).to eq(product.id)
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
      it 'should have created orders' do
        expect(plan.work_orders.length).to eq(processes.length)
      end
      it 'should have correctly set up work orders' do
        plan.work_orders.zip(processes, product_options).each do |order, pro, opts|
          expect(order).to be_queued
          expect(order.process).to eq(pro)
          expect(order.work_order_module_choices.map(&:aker_process_modules_id)).to eq(opts)
        end
      end
      it 'should have destroyed old orders' do
        expect(WorkOrder.where(id: @old_order.id)).to be_empty
      end
      it 'orders should have correct sets' do
        plan.work_orders.each_with_index do |order, i|
          if i==0
            expect(order.original_set_uuid).to eq(plan.original_set_uuid)
            expect(order.set_uuid).to eq(old_locked_set.uuid)
          else
            expect(order.original_set_uuid).to be_nil
            expect(order.set_uuid).to be_nil
          end
        end
      end
    end

    context 'when an order has already been dispatched' do
      let(:plan) do
        plan = make_plan_with_orders
        @old_order = plan.work_orders.first
        @old_order.update_attributes!(status: 'active')
        plan
      end

      # product options different from the defaults
      let(:product_options) do
        processes.map { |pro| [pro.process_modules[1].id] }
      end

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /in progress/
      end
      it 'should still be active' do
        expect(plan).to be_active
      end
      it 'should still have orders' do
        expect(plan.work_orders.length).to eq(processes.length)
      end
      it 'should have the same orders as before' do
        expect(plan.work_orders.first).to eq(@old_order)
      end
    end

    context 'when no product options are supplied' do
      let(:plan) { create(:work_plan, original_set_uuid: set.uuid, project_id: project.id) }
      let(:params) do
        {
          product_id: product.id,
        }
      end

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to eq "Please select an option to proceed"
      end
      it 'should not set the product in the plan' do
        expect(plan.product_id).to be_nil
      end
      it 'should not set the comment' do
        expect(plan.comment).to be_nil
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
      it 'should not have orders' do
        expect(plan.work_orders).to be_empty
      end
    end

    context 'when no product id is supplied' do

      let(:plan) { create(:work_plan, original_set_uuid: set.uuid, project_id: project.id) }
      let(:params) do
        {
          comment: 'commentary',
          product_options: product_options.to_json,
        }
      end

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to eq "Please select an option to proceed"
      end
      it 'should not set the product in the plan' do
        expect(plan.product_id).to be_nil
      end
      it 'should not set the comment' do
        expect(plan.comment).to be_nil
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
      it 'should not have orders' do
        expect(plan.work_orders).to be_empty
      end
    end
  end

  describe 'selecting a data release strategy' do
    context 'when a data release strategy is know' do
      let(:plan) do
        plan = make_plan_with_orders
        plan.update_attributes!(data_release_strategy_id: nil)
        plan
      end
      let(:params) do { data_release_strategy_id: drs.id } end

      it { expect(@result).to be_truthy }
      it 'should produce no error messages' do
        expect(messages).to be_empty
      end
      it 'should set the data release strategy in the plan' do
        expect(plan.data_release_strategy_id).to eq(drs.id)
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
    end
    context 'when a data release strategy is not known' do
      let(:plan) do
        plan = make_plan_with_orders
        plan.update_attributes!(data_release_strategy_id: nil)
        plan
      end
      let(:params) do { data_release_strategy_id: SecureRandom.uuid } end

      it { expect(@result).to be_falsey }
      it 'should produce error messages' do
        expect(messages[:error]).to match /No data release strategy could be found with uuid*/i
      end
      it 'should not set the data release strategy in the plan' do
        plan.reload
        expect(plan.data_release_strategy_id).to eq(nil)
      end
      it 'should still be in construction' do
        expect(plan).to be_in_construction
      end
    end
  end

  describe 'altering product modules' do
    let(:plan) do
      plan = make_plan_with_orders
      plan.work_orders.first.update_attributes!(status: 'active')
      plan
    end

    let(:old_orders) {
      plan.work_orders.to_a
    }

    let(:params) do
      {
        work_order_id: old_orders[1].id,
        work_order_modules: module_ids.to_json,
      }
    end

    let(:module_ids) { [processes[1].process_modules[1].id] }

    let(:module_cost) { 15 }

    def stub_billing_facade
      super
      allow(BillingFacadeClient).to receive(:get_cost_information_for_module).and_return(module_cost)
    end

    context 'when the order is queued' do
      it { expect(@result).to be_truthy }
      it 'should not produce an error message' do
        expect(messages).to be_empty
      end
      it 'should still be active' do
        expect(plan).to be_active
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(old_orders)
      end
      it 'should have correctly set the modules for the orders' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[1].id])
      end
    end

    context 'when the order is active' do
      let(:params) do
        {
          work_order_id: old_orders[0].id,
          work_order_modules: [processes[0].process_modules[1].id].to_json,
        }
      end
      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /order.*cannot.*update/i
      end
      it 'should still be active' do
        expect(plan).to be_active
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(old_orders)
      end
      it 'should still have the original modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[0].id])
      end
    end

    context 'when the modules are not valid for the process' do
      let(:module_ids) { [processes[1].process_modules[0].id]*2 }

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match Regexp.new('modules.*valid.*'+Regexp.escape(processes[1].name))
      end
      it 'should still be active' do
        expect(plan).to be_active
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(old_orders)
      end
      it 'should still have the original modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[0].id])
      end
    end

    context 'when the modules cannot be costed' do
      let(:module_cost) { nil }

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /module/i
      end
      it 'should still be active' do
        expect(plan).to be_active
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(old_orders)
      end
      it 'should still have the original modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[0].id])
      end
    end
    context 'when there is a selected value' do
      def work_order_module
        processes.map(&:process_modules).flatten.reduce({}) do |memo, mod|
          mod.update_attributes(min_value:1, max_value: 5)
          memo[mod.id.to_s] = {
            selected_value: selected_value
          }
          memo
        end
      end
      let(:params) do
        {
          work_order_id: old_orders[1].id,
          work_order_modules: module_ids.to_json,
          work_order_module: work_order_module
        }
      end
      context 'when the module selected values are not valid' do
        let(:selected_value) { 7 }
        it { expect(@result).to be_falsey }
        it 'should produce an error message' do
          expect(messages[:error]).to match Regexp.new('Update.*failed.*')
        end
      end
      context 'when the module selected values are valid' do
        let(:selected_value) { 3 }
        it { expect(@result).to be_truthy }
      end

    end

  end

  describe 'dispatching the first order' do
    let(:plan) { make_plan_with_orders }
    let(:orders) { plan.work_orders }
    let(:params) do
      {
        comment: 'a comment',
        priority: 'high',
        work_order_id: orders[0].id,
        work_order_modules: [processes[0].process_modules[1].id].to_json,
      }
    end
    let(:dispatch) { true }

    def stub_billing_facade
      super
      allow(BillingFacadeClient).to receive(:get_cost_information_for_module).and_return(13)
    end

    def extra_stubbing
      @sent_to_lims = false
      @sent_event = false
      @finalised_set = false
      allow_any_instance_of(WorkOrderDispatcher).to receive(:dispatch) { @sent_to_lims = true }
      allow_any_instance_of(WorkOrder).to receive(:generate_dispatched_event) { @sent_event = true }
      allow_any_instance_of(WorkOrderDecorator).to receive(:finalise_set) { @finalised_set = true }
      allow_any_instance_of(WorkOrderSplitter::ByContainer).to receive(:split).with(plan.work_orders.first)
      stub_project
      stub_stamps
      stub_broker_connection
      stub_data_release_strategy
    end

    context 'when the order is queued' do
      it { expect(@result).to be_truthy }
      it 'should not produce an error message' do
        expect(messages).to be_empty
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(orders)
      end
      it 'should have orders with the correct modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[1].id])
        expect(modules[1]).to eq([processes[1].process_modules[0].id])
      end
      it 'should have finalised the set' do
        expect(@finalised_set).to eq(true)
      end
      it 'should have sent the order' do
        expect(@sent_to_lims).to eq(true)
      end
      it 'should have generated an event' do
        expect(@sent_event).to eq(true)
      end
      it 'should have a comment' do
        expect(plan.reload.comment).to eq 'a comment'
      end
      it 'should have a priority' do
        expect(plan.reload.priority).to eq 'high'
      end
    end

    context 'when the order is active' do
      let(:old_date) { Time.now.yesterday }
      let(:plan) do
        plan = make_plan_with_orders
        plan.work_orders[0].update_attributes(status: 'active', dispatch_date: old_date)
        plan
      end
      let(:params) do
        {
          work_order_id: orders[0].id,
          work_order_modules: [processes[0].process_modules[1].id].to_json,
        }
      end

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /cannot.*dispatch/i
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(orders)
      end
      it 'should not have changed the order modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[0].id])
      end
      it 'should still be active' do
        expect(plan.reload).to be_active
      end
      it 'should not have finalised the set' do
        expect(@finalised_set).to eq(false)
      end
      it 'should not have sent the order' do
        expect(@sent_to_lims).to eq(false)
      end
      it 'should not have generated an event' do
        expect(@sent_event).to eq(false)
      end
      it 'should not have changed the order status' do
        expect(orders[0].reload).to be_active
      end
      it 'should not have changed the dispatch date' do
        expect(orders[0].reload.dispatch_date.to_i).to eq(old_date.to_i)
      end
    end

    context 'when the set is empty' do
      let(:set) { make_set(true, true, locked_set) }

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /set.*empty/i
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(orders)
      end
      it 'should not have changed the order modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[0].id])
      end
      it 'should still be in construction' do
        expect(plan.reload).to be_in_construction
      end
      it 'should not have finalised the set' do
        expect(@finalised_set).to eq(false)
      end
      it 'should not have sent the order' do
        expect(@sent_to_lims).to eq(false)
      end
      it 'should not have generated an event' do
        expect(@sent_event).to eq(false)
      end
      it 'should not have changed the order status' do
        expect(orders[0].reload).to be_queued
      end
      it 'should not have changed the dispatch date' do
        expect(orders[0].reload.dispatch_date).to be_nil
      end
    end

    context 'when the set materials are unavailable' do
      let(:set) { make_set(false, false, locked_set) }

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /material.*available/i
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(orders)
      end
      it 'should not have changed the order modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[0].id])
      end
      it 'should still be in construction' do
        expect(plan.reload).to be_in_construction
      end
      it 'should not have finalised the set' do
        expect(@finalised_set).to eq(false)
      end
      it 'should not have sent the order' do
        expect(@sent_to_lims).to eq(false)
      end
      it 'should not have generated an event' do
        expect(@sent_event).to eq(false)
      end
      it 'should not have changed the order status' do
        expect(orders[0].reload).to be_queued
      end
      it 'should not have changed the dispatch date' do
        expect(orders[0].reload.dispatch_date).to be_nil
      end
    end

    context 'when the materials are not authorised' do
      def stub_stamps
       allow(StampClient::Permission).to receive(:check_catch).with({
         permission_type: :consume,
         names: user_and_groups,
         material_uuids: set._material_uuids,
       }).and_return false
       allow(StampClient::Permission).to receive(:unpermitted_uuids).and_return([set._material_uuids.first])
      end
      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /not authori[sz]ed.*materials/i
      end
      it 'should have tried to authorise the materials' do
        expect(StampClient::Permission).to have_received(:check_catch).with({
         permission_type: :consume,
         names: user_and_groups,
         material_uuids: set._material_uuids,
       })
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(orders)
      end
      it 'should not have changed the order modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[0].id])
      end
      it 'should still be in construction' do
        expect(plan.reload).to be_in_construction
      end
      it 'should not have finalised the set' do
        expect(@finalised_set).to eq(false)
      end
      it 'should not have sent the order' do
        expect(@sent_to_lims).to eq(false)
      end
      it 'should not have generated an event' do
        expect(@sent_event).to eq(false)
      end
      it 'should not have changed the order status' do
        expect(orders[0].reload).to be_queued
      end
      it 'should not have changed the dispatch date' do
        expect(orders[0].reload.dispatch_date).to be_nil
      end
    end

    context 'when the project is not authorised' do
      def stub_project
        ex = AkerPermissionGem::NotAuthorized.new("Not authorised")
        allow(StudyClient::Node).to receive(:authorize!).with(:spend, project.id, user_and_groups).and_raise ex
      end
      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /not authori[sz]ed/i
      end
      it 'should have tried to authorise the project' do
        expect(StudyClient::Node).to have_received(:authorize!).with(:spend, project.id, user_and_groups)
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(orders)
      end
      it 'should not have changed the order modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[0].id])
      end
      it 'should still be in construction' do
        expect(plan.reload).to be_in_construction
      end
      it 'should not have finalised the set' do
        expect(@finalised_set).to eq(false)
      end
      it 'should not have sent the order' do
        expect(@sent_to_lims).to eq(false)
      end
      it 'should not have generated an event' do
        expect(@sent_event).to eq(false)
      end
      it 'should not have changed the order status' do
        expect(orders[0].reload).to be_queued
      end
      it 'should not have changed the dispatch date' do
        expect(orders[0].reload.dispatch_date).to be_nil
      end
    end
    context 'when the data release strategy is not valid' do
      def stub_data_release_strategy
        allow(DataReleaseStrategyClient).to receive(:find_strategies_by_user).and_return([])
      end
      it "should return false" do
        expect(@result).to be_falsey
      end
      it 'should produce an error message' do
        expect(messages[:error]).to match /The current user cannot select the Data release strategy provided./i
      end
      it 'should not have sent the order' do
        expect(@sent_to_lims).to eq(false)
      end
    end
  end

  describe 'dispatching a subsequent order' do

    let(:orders) { plan.work_orders }
    let(:params) do
      {
        work_order_id: orders[1].id,
        work_order_modules: [processes[1].process_modules[1].id].to_json,
      }
    end
    let(:dispatch) { true }

    def stub_billing_facade
      super
      allow(BillingFacadeClient).to receive(:get_cost_information_for_module).and_return(13)
    end

    def extra_stubbing
      @sent_to_lims = false
      @sent_event = false
      allow_any_instance_of(WorkOrderDispatcher).to receive(:dispatch) { @sent_to_lims = true }
      allow_any_instance_of(WorkOrderSplitter::ByContainer).to receive(:split).with(plan.work_orders.second)
      allow_any_instance_of(WorkOrder).to receive(:generate_dispatched_event) { @sent_event = true }
      stub_project
      stub_stamps
      stub_broker_connection
    end

    context 'when the broker is broken' do
      let(:plan) { make_plan_with_orders }
      before do
        allow(BrokerHandle).to receive(:connected?).and_return(false)
      end
      it { expect(@result).to be_falsey }
    end

    context 'when the first order is queued' do
      let(:plan) { make_plan_with_orders }
      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to be_present
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(orders)
      end
      it 'should not have changed the order modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[0].id])
      end
      it 'should still be in construction' do
        expect(plan.reload).to be_in_construction
      end
      it 'should not have sent the order' do
        expect(@sent_to_lims).to eq(false)
      end
      it 'should not have generated an event' do
        expect(@sent_event).to eq(false)
      end
      it 'should not have changed the order status' do
        expect(orders[1].reload).to be_queued
      end
      it 'should not have changed the dispatch date' do
        expect(orders[1].reload.dispatch_date).to be_nil
      end
    end

    context 'when the first order is active' do
      let(:plan) do
        plan = make_plan_with_orders
        plan.work_orders.first.update_attributes!(status: 'active')
        plan
      end
      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to be_present
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(orders)
      end
      it 'should not have changed the order modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[0].id])
      end
      it 'should still be active' do
        expect(plan.reload).to be_active
      end
      it 'should not have sent the order' do
        expect(@sent_to_lims).to eq(false)
      end
      it 'should not have generated an event' do
        expect(@sent_event).to eq(false)
      end
      it 'should not have changed the order status' do
        expect(orders[1].reload).to be_queued
      end
      it 'should not have changed the dispatch date' do
        expect(orders[1].reload.dispatch_date).to be_nil
      end
    end

    context 'when the project is not authorised' do
      let(:plan) do
        plan = make_plan_with_orders
        plan.work_orders.first.update_attributes!(status: 'concluded', finished_set_uuid: locked_set.uuid)
        plan
      end

      def stub_project
        ex = AkerPermissionGem::NotAuthorized.new("Not authorised")
        allow(StudyClient::Node).to receive(:authorize!).with(:spend, project.id, user_and_groups).and_raise ex
      end

      it { expect(@result).to be_falsey }
      it 'should have tried to authorise the project' do
        expect(StudyClient::Node).to have_received(:authorize!).with(:spend, project.id, user_and_groups)
      end
      it 'should produce an error message' do
        expect(messages[:error]).to match /not.*authori[sz]ed/i
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(orders)
      end
      it 'should not have changed the order modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[0].id])
      end
      it 'should still be active' do
        expect(plan.reload).to be_active
      end
      it 'should not have sent the order' do
        expect(@sent_to_lims).to eq(false)
      end
      it 'should not have generated an event' do
        expect(@sent_event).to eq(false)
      end
      it 'should not have changed the order status' do
        expect(orders[1].reload).to be_queued
      end
      it 'should not have changed the dispatch date' do
        expect(orders[1].reload.dispatch_date).to be_nil
      end
    end

    context 'when the materials are not authorised' do
      let(:plan) do
        plan = make_plan_with_orders
        plan.work_orders.first.update_attributes!(status: 'concluded', finished_set_uuid: locked_set.uuid)
        plan
      end

      def stub_stamps
       allow(StampClient::Permission).to receive(:check_catch).with({
         permission_type: :consume,
         names: user_and_groups,
         material_uuids: locked_set._material_uuids,
       }).and_return false
       allow(StampClient::Permission).to receive(:unpermitted_uuids).and_return([locked_set._material_uuids.first])
      end

      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to match /not authori[sz]ed.*materials/i
      end
      it 'should have tried to authorise the materials' do
        expect(StampClient::Permission).to have_received(:check_catch).with({
         permission_type: :consume,
         names: user_and_groups,
         material_uuids: locked_set._material_uuids,
       })
      end
      it 'should produce an error message' do
        expect(messages[:error]).to match /not.*authori[sz]ed/i
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(orders)
      end
      it 'should not have changed the order modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[0].id])
      end
      it 'should still be active' do
        expect(plan.reload).to be_active
      end
      it 'should not have sent the order' do
        expect(@sent_to_lims).to eq(false)
      end
      it 'should not have generated an event' do
        expect(@sent_event).to eq(false)
      end
      it 'should not have changed the order status' do
        expect(orders[1].reload).to be_queued
      end
      it 'should not have changed the dispatch date' do
        expect(orders[1].reload.dispatch_date).to be_nil
      end
    end

    context 'when the order is already active' do
      let(:plan) do
        plan = make_plan_with_orders
        plan.work_orders.first.update_attributes!(status: 'concluded', finished_set_uuid: locked_set.uuid)
        plan.work_orders[1].update_attributes!(status: 'active')
        plan
      end
      it { expect(@result).to be_falsey }
      it 'should produce an error message' do
        expect(messages[:error]).to be_present
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(orders)
      end
      it 'should not have changed the order modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[0].id])
      end
      it 'should still be active' do
        expect(plan.reload).to be_active
      end
      it 'should not have sent the order' do
        expect(@sent_to_lims).to eq(false)
      end
      it 'should not have generated an event' do
        expect(@sent_event).to eq(false)
      end
      it 'should not have changed the order status' do
        expect(orders[1].reload).to be_active
      end
      it 'should not have changed the dispatch date' do
        expect(orders[1].reload.dispatch_date).to be_nil
      end
    end

    context 'when the order is ready to be dispatched' do
      let(:plan) do
        plan = make_plan_with_orders
        plan.work_orders.first.update_attributes!(status: 'concluded', finished_set_uuid: locked_set.uuid)
        plan
      end
      it { expect(@result).to be_truthy }
      it 'should not produce an error message' do
        expect(messages).to be_empty
      end
      it 'should have the same work orders' do
        expect(plan.work_orders.reload).to eq(orders)
      end
      it 'should have updated the order modules' do
        orders = plan.work_orders.reload
        modules = orders.map do |order|
          WorkOrderModuleChoice.where(work_order_id: order.id).map(&:aker_process_modules_id)
        end
        expect(modules[0]).to eq([processes[0].process_modules[0].id])
        expect(modules[1]).to eq([processes[1].process_modules[1].id])
      end
      it 'should be active' do
        expect(plan.reload).to be_active
      end
      it 'should have sent the order' do
        expect(@sent_to_lims).to eq(true)
      end
      it 'should have generated an event' do
        expect(@sent_event).to eq(true)
      end
    end
  end
end
