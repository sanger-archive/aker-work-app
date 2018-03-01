require 'rails_helper'

RSpec.describe WorkOrder, type: :model do
  let(:catalogue) { create(:catalogue) }
  let(:product) { create(:product, name: 'Solylent Green', product_version: 3, catalogue: catalogue) }
  let(:process) do
    pro = create(:aker_process, name: 'Baking', external_id: 15)
    create(:aker_product_process, product: product, aker_process: pro, stage: 0)
    pro
  end
  let(:project) { make_node('Operation Wolf', 'S1001', 41, 40, false, true, SecureRandom.uuid) }
  let(:subproject) { make_node('Operation Thunderbolt', 'S1001-0', 42, project.id, true, false, nil) }

  let(:plan) { process; create(:work_plan, project_id: subproject.id, product: product, comment: 'hello', desired_date: '2020-01-01') }

  def make_uuid
    SecureRandom.uuid
  end

  before do
    @barcode_index = 100
    bfc = double('BillingFacadeClient')
    stub_const("BillingFacadeClient", bfc)
    allow(bfc).to receive(:validate_process_module_name) do |name|
      !name.starts_with? 'x'
    end
  end

  def make_barcode
    @barcode_index += 1
    "AKER-#{@barcode_index}"
  end

  def make_set(size=6)
    uuid = make_uuid
    s = double(:set, uuid: uuid, id: uuid, meta: { 'size' => size })
    allow(SetClient::Set).to receive(:find).with(s.uuid).and_return([s])
    return s
  end

  def make_node(name, cost_code, id, parent_id, is_sub, is_proj, data_release_uuid)
    n = double('node', name: name, cost_code: cost_code, id: id, parent_id: parent_id, subproject?: is_sub, project?: is_proj,
               node_uuid: make_uuid, data_release_uuid: data_release_uuid)
    allow(StudyClient::Node).to receive(:find).with(n.id).and_return([n])
    return n
  end

  def make_result_set(items)
    rs = double('result_set', has_next?: false, length: items.length, to_a: items)
    allow(rs).to receive(:map) { |&block| items.map(&block) }
    allow(rs).to receive(:each) { |&block| items.each(&block) }
    allow(rs).to receive(:all?) { |&block| items.all?(&block) }
    return double('result_set_wrapper', result_set: rs)
  end

  def make_materials(num=3)
    @materials = (1..3).map do |i|
      attributes = {
        'gender' => (i%2==0) ? 'male' : 'female',
        'donor_id' => 'donor #{i}',
        'phenotype' => 'phenotype #{i}',
        'scientific_name' => 'Mouse',
        'available' => true,
      }
      double(:material, id: make_uuid, attributes: attributes)
    end
    allow(MatconClient::Material).to receive(:where) do |args|
      ids = args['_id']['$in']
      found = ids.map do |id|
        @materials.find { |m| m.id==id }
      end
      make_result_set(found)
    end
    return @materials
  end

  def make_set_with_materials
    @set = make_set

    make_materials
    allow(@set).to receive(:materials).and_return(@materials)
    allow(SetClient::Set).to receive(:find_with_materials).
      with(@set.uuid).and_return([@set])
    return @set
  end

  describe '#finished_set' do
    context 'when the work order has a finished set uuid' do
      let(:finished_set) { make_set(6) }
      let(:wo) { build(:work_order, finished_set_uuid: finished_set.uuid) }
      it "should return the finished set" do
        expect(wo.finished_set).to eq finished_set
      end
    end
    context 'when the work order has no finished set uuid' do
      let(:wo) { build(:work_order) }
      it "should return nil" do
        expect(wo.finished_set).to be_nil
      end
    end
  end

  describe "#set" do
    context "when work order has a set" do
      before do
        @set = make_set(6)
        @wo = build(:work_order, set: @set)
      end
      it "should return the set" do
        expect(@wo.set).to be @set
      end
    end
    context "when work order has a set uuid" do
      before do
        @set = make_set(6)
        @wo = build(:work_order, set_uuid: @set.uuid)
      end
      it "should look up the set and return it" do
        expect(@wo.set).to eq @set
      end
    end
    context "when work order has no set" do
      before do
        @wo = build(:work_order, set_uuid: nil, set: nil)
      end
      it "should return nil" do
        expect(@wo.set).to be_nil
      end
    end

    context "when set is assigned in the work order" do
      before do
        @wo = build(:work_order)
        @set = make_set
      end

      it "should update the set_uuid" do
        expect(@wo.set).to be_nil
        expect(@wo.set_uuid).to be_nil
        @wo.set=@set
        expect(@wo.set).to be(@set)
        expect(@wo.set_uuid).to eq(@set.uuid)
      end
    end
    context "when set_uuid is assigned in the work order" do
      before do
        @wo = build(:work_order)
        @set = make_set
      end

      it "should update the set" do
        expect(@wo.set).to be_nil
        expect(@wo.set_uuid).to be_nil
        @wo.set_uuid=@set.uuid
        expect(@wo.set).to be(@set)
        expect(@wo.set_uuid).to eq(@set.uuid)
      end
    end
  end

  describe "#original_set" do
    context "when work order has an original_set" do
      before do
        @set = make_set(6)
        @wo = build(:work_order, original_set: @set)
      end
      it "should return the set" do
        expect(@wo.original_set).to be @set
      end
    end
    context "when work order has an original_set_uuid" do
      before do
        @set = make_set(6)
        @wo = build(:work_order, original_set_uuid: @set.uuid)
      end
      it "should look up the set and return it" do
        expect(@wo.original_set).to be @set
      end
    end
    context "when work order has no original set" do
      before do
        @wo = build(:work_order, original_set_uuid: nil, original_set: nil)
      end
      it "should return nil" do
        expect(@wo.original_set).to be_nil
      end
    end

    context "when the Set Client can not find the original set" do
      before do
        @uuid = SecureRandom.uuid
        allow(SetClient::Set).to receive(:find).with(@uuid).and_raise(JsonApiClient::Errors::NotFound, "a message")
        @wo = build(:work_order, original_set_uuid: @uuid)
      end

      it "should return nil" do
        expect(@wo.original_set).to be_nil
      end
    end

    context "when original_set is assigned in the work order" do
      before do
        @wo = build(:work_order, original_set: nil, original_set_uuid: nil)
        @set = make_set
      end

      it "should update the original_set_uuid" do
        expect(@wo.original_set).to be_nil
        expect(@wo.original_set_uuid).to be_nil
        @wo.original_set=@set
        expect(@wo.original_set).to be(@set)
        expect(@wo.original_set_uuid).to eq(@set.uuid)
      end
    end
    context "when original_set_uuid is assigned in the work order" do
      before do
        @wo = build(:work_order, original_set: nil, original_set_uuid: nil)
        @set = make_set
      end

      it "should update the original_set" do
        expect(@wo.original_set).to be_nil
        expect(@wo.original_set_uuid).to be_nil
        @wo.original_set_uuid=@set.uuid
        expect(@wo.original_set).to be(@set)
        expect(@wo.original_set_uuid).to eq(@set.uuid)
      end
    end
  end

  describe "#lims_data" do

    def make_container(materials)
      slots = materials.each_with_index.map do |material,i|
        double('slot', material_id: material&.id, address: (i+1).to_s)
      end
      @container = double('container', barcode: make_barcode, num_of_rows: 1, num_of_cols: materials.length, slots: slots)

      allow(MatconClient::Container).to receive(:where) do |args|
        material_ids = args['slots.material']['$in']
        containers = []
        if @container.slots.any? { |slot| material_ids.include? slot.material_id }
          containers = [@container]
        end
        make_result_set(containers)
      end
      return @container
    end

    let(:order) do
      create(:work_order, process_id: process.id, work_plan: plan, set_uuid: @set.id, order_index: 0)
    end

    let(:modules) do
      (1...3).map { |i| create(:aker_process_module, name: "Module#{i}", aker_process_id: process.id) }
    end

    before do
      make_set_with_materials
      make_container(@materials)
      modules.each_with_index { |m,i| WorkOrderModuleChoice.create(work_order: order, process_module: m, position: i)}
    end

    context 'when some of the materials are unavailable' do
      before do
        @materials[0].attributes['available'] = false
      end

      it "should raise an exception" do
        expect { order.lims_data }.to raise_error(/materials.*available/)
      end
    end

    context 'when data is calculated' do
      it "should return the lims_data" do
        data = order.lims_data[:work_order]
        expect(data[:process_name]).to eq(process.name)
        expect(data[:process_id]).to eq(process.external_id)
        expect(data[:work_order_id]).to eq(order.id)
        expect(data[:comment]).to eq(plan.comment)
        expect(data[:project_uuid]).to eq(project.node_uuid)
        expect(data[:project_name]).to eq(project.name)
        expect(data[:data_release_uuid]).to eq(project.data_release_uuid)
        expect(data[:cost_code]).to eq(subproject.cost_code)
        expect(data[:desired_date]).to eq(plan.desired_date)
        expect(data[:modules]).to eq(["Module1", "Module2"])
        material_data = data[:materials]
        expect(material_data.length).to eq(@materials.length)
        @materials.zip(material_data).each do |mat, dat|
          slot = @container.slots.find { |slot| slot.material_id==mat.id }
          expect(dat[:_id]).to eq(mat.id)
          expect(dat[:container]).to eq({ barcode: @container.barcode, address: slot.address, num_of_rows: @container.num_of_rows, num_of_cols: @container.num_of_cols })
          expect(dat[:gender]).to eq(mat.attributes['gender'])
          expect(dat[:donor_id]).to eq(mat.attributes['donor_id'])
          expect(dat[:phenotype]).to eq(mat.attributes['phenotype'])
          expect(dat[:scientific_name]).to eq(mat.attributes['scientific_name'])
        end
      end
    end

    context 'when module name is not valid' do
      before do
        m = create(:aker_process_module, name: "xModule", aker_process_id: process.id)
        WorkOrderModuleChoice.create(work_order: order, process_module: m, position: 2)
      end
      it 'should raise an exception' do
        expect { order.lims_data }.to raise_exception('Process module could not be validated: ["xModule"]')
      end
    end

  end

  describe '#module_choices' do
    let(:order) { create(:work_order, process: process, work_plan: plan) }
    let(:modules) do
      (1...3).map { |i| create(:aker_process_module, name: "Module#{i}", aker_process_id: process.id) }
    end

    before do
      modules.each_with_index { |m,i| WorkOrderModuleChoice.create(work_order: order, process_module: m, position: i)}
    end

    it 'returns the module names' do
      expect(order.module_choices).to eq(["Module1", "Module2"])
    end
  end

  describe '#validate_module_names' do
    let(:order) { create(:work_order, process: process, work_plan: plan) }

    context 'when modules are all valid' do
      it 'should not raise an exception' do
        expect { order.validate_module_names(['alpha', 'beta']) }.not_to raise_exception
      end
    end
    context 'when any modules are invalid' do
      it 'should raise an exception' do
        expect { order.validate_module_names(['alpha', 'xbeta', 'xgamma', 'delta']) }
          .to raise_exception('Process module could not be validated: ["xbeta", "xgamma"]')
      end
    end
  end

  describe "#describe_containers" do
    def make_container(materials)
      slots = materials.each_with_index.map do | mat, i |
        double('slot', material_id: mat&.id, address: "A:#{i+1}")
      end
      return double('container', barcode: make_barcode, num_of_rows: 1, num_of_cols: materials.length, slots: slots)
    end

    before do
      make_set_with_materials

      @plate = make_container([nil, nil] + @materials[0..1]) # plate with some empty slots
      @tube = make_container(@materials[2..2]) # tube with one material
      @material_ids = @materials.map { |m| m.id }
      allow(MatconClient::Container).to receive(:where).
        with({"slots.material" => { "$in" => @material_ids }}).
        and_return(make_result_set([@plate, @tube]))
      @wo = build(:work_order)
    end

    it "should load the descriptions into the data" do
      material_data = @materials.map do |m|
        {
          _id: m.id,
          container: nil,
          gender: m.attributes['gender'],
          donor_id: m.attributes['donor_id'],
          phenotype: m.attributes['phenotype'],
          scientific_name: m.attributes['scientific_name']
        }
      end

      @wo.describe_containers(@material_ids, material_data)

      expected = [
        { barcode: @plate.barcode, address: 'A:3', num_of_cols: @plate.num_of_cols, num_of_rows: @plate.num_of_rows },
        { barcode: @plate.barcode, address: 'A:4', num_of_cols: @plate.num_of_cols, num_of_rows: @plate.num_of_rows },
        { barcode: @tube.barcode, address: 'A:1', num_of_cols: 1, num_of_rows: 1 },
      ]
      expect(material_data.length).to eq(expected.length)
      expected.zip(material_data).each do | exp, data |
        expect(data[:container]).to eq(exp)
      end
    end
  end

  describe "#create_locked_set" do
    before do
      @original_set = make_set
      @new_set = make_set
      allow(@original_set).to receive(:create_locked_clone).and_return(@new_set)
      @wo = create(:work_order, id: 42, work_plan: plan, set_uuid: nil, set: nil, original_set_uuid: @original_set.uuid)
    end

    it "should call create_locked_clone on the original set" do
      @wo.create_locked_set
      expect(@original_set).to have_received(:create_locked_clone)
    end
  end

  describe "#generate_completed_and_cancel_event" do
    context 'if work order does not have status completed or cancelled' do
      it 'generates an event using the EventService' do
        wo = build(:work_order)
        EventService ||= double('EventService')
        expect(EventService).not_to receive(:publish).with(an_instance_of(WorkOrderEventMessage))
        expect{wo.generate_completed_and_cancel_event}.to raise_exception('You cannot generate an event from a work order that has not been completed.')
      end
    end

    context 'if work order does have status completed or cancelled' do
      it 'generates an event using the EventService' do
        wo = build(:work_order, status: 'completed')
        EventService ||= double('EventService')
        allow(EventService).to receive(:publish)
        allow(BillingFacadeClient).to receive(:send_event).with(wo, 'completed')
        expect(EventService).to receive(:publish).with(an_instance_of(WorkOrderEventMessage))
        wo.generate_completed_and_cancel_event
      end
    end
  end

   describe "#generate_submitted_event" do
    context 'if work order does not have status active' do
      it 'generates an event using the EventService' do
        wo = build(:work_order)
        EventService ||= double('EventService')
        allow(BillingFacadeClient).to receive(:send_event).with(wo, 'submitted')
        expect(EventService).not_to receive(:publish).with(an_instance_of(WorkOrderEventMessage))
        expect{wo.generate_submitted_event}.to raise_exception('You cannot generate an submitted event from a work order that is not active.')
      end
    end

    context 'if work order does have status active' do
      it 'generates an event using the EventService' do
        wo = build(:work_order, status: 'active')
        EventService ||= double('EventService')
        allow(EventService).to receive(:publish)
        allow(BillingFacadeClient).to receive(:send_event).with(wo, 'submitted')
        expect(EventService).to receive(:publish).with(an_instance_of(WorkOrderEventMessage))
        wo.generate_submitted_event
      end
    end
  end

  describe "#total_tat" do
    it "calculates the total TAT" do
      process = build(:process, TAT: 4)
      order = build(:work_order, process: process)
      expect(order.total_tat).to eq(4)
    end
  end

end