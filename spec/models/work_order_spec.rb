require 'rails_helper'

RSpec.describe WorkOrder, type: :model do

  def make_uuid
    SecureRandom.uuid
  end

  before do
    @barcode_index = 100
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

  def make_proposal
    proposal = double('proposal', name: 'Operation Wolf', cost_code: 'S1001', id: 42)
    allow(StudyClient::Node).to receive(:find).with(proposal.id).and_return([proposal])
    return proposal
  end

  def make_result_set(items)
    rs = double('result_set', has_next?: false, length: items.length)
    allow(rs).to receive(:map) { |&block| items.map(&block) }
    allow(rs).to receive(:each) { |&block| items.each(&block) }
    return double('result_set_wrapper', result_set: rs)
  end

  def make_materials(num=3)
    @materials = (1..3).map do |i|
      attributes = {
        'gender' => (i%2==0) ? 'male' : 'female',
        'donor_id' => 'donor #{i}',
        'phenotype' => 'phenotype #{i}',
        'common_name' => 'Mouse',
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

  describe "#proposal" do
    context "when the work order has a proposal id" do
      before do
        @proposal = make_proposal
        @wo = build(:work_order, proposal_id: @proposal.id)
      end

      it "should find and return the proposal" do
        expect(@wo.proposal).to eq(@proposal)
      end
    end
    context "when the work order has no proposal id" do
      before do
        @wo = build(:work_order, proposal_id: nil)
      end

      it "should return nil" do
        expect(@wo.proposal).to be_nil
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

    context 'when data is calculated' do
      before do
        make_set_with_materials
        make_container(@materials)
        @proposal = make_proposal
        product = build(:product, name: 'Soylent Green', product_version: 3)
        @wo = build(:work_order, product: product, proposal_id: @proposal.id, set_uuid: @set.id,
                    id: 616, comment: 'hello', desired_date: '2020-01-01')
      end

      it "should return the lims_data" do
        data = @wo.lims_data()[:work_order]
        expect(data[:product_name]).to eq(@wo.product.name)
        expect(data[:product_version]).to eq(@wo.product.product_version)
        expect(data[:work_order_id]).to eq(@wo.id)
        expect(data[:comment]).to eq(@wo.comment)
        expect(data[:proposal_id]).to eq(@proposal.id)
        expect(data[:proposal_name]).to eq(@proposal.name)
        expect(data[:cost_code]).to eq(@proposal.cost_code)
        expect(data[:desired_date]).to eq(@wo.desired_date)
        material_data = data[:materials]
        expect(material_data.length).to eq(@materials.length)
        @materials.zip(material_data).each do |mat, dat|
          slot = @container.slots.find { |slot| slot.material_id==mat.id }
          expect(dat[:material_id]).to eq(mat.id)
          expect(dat[:container]).to eq("#{@container.barcode} #{slot.address}")
          expect(dat[:gender]).to eq(mat.attributes['gender'])
          expect(dat[:donor_id]).to eq(mat.attributes['donor_id'])
          expect(dat[:phenotype]).to eq(mat.attributes['phenotype'])
          expect(dat[:common_name]).to eq(mat.attributes['common_name'])
        end
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
          material_id: m.id,
          container: nil,
          gender: m.attributes['gender'],
          donor_id: m.attributes['donor_id'],
          phenotype: m.attributes['phenotype'],
          common_name: m.attributes['common_name']
        }
      end

      @wo.describe_containers(@material_ids, material_data)

      expected = [ "#{@plate.barcode} A:3", "#{@plate.barcode} A:4", "#{@tube.barcode}"]
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
      @wo = create(:work_order, id: 42, set_uuid: nil, set: nil, original_set_uuid: @original_set.uuid)
    end

    it "should call create_locked_clone on the original set" do
      @wo.create_locked_set
      expect(@original_set).to have_received(:create_locked_clone)
    end
  end

  describe "#generate_event" do
    it 'generates an event using the EventService' do
      #set = make_set(6)
      wo = build(:work_order)
      EventService = double('EventService')
      allow(EventService).to receive(:publish)
      expect(EventService).to receive(:publish).with(an_instance_of(EventMessage))
      wo.generate_event
    end
  end
end
