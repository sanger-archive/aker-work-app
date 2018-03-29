require 'rails_helper'

RSpec.describe 'Jobs', type: :model do
  let(:catalogue) { create(:catalogue) }
  let(:product) { create(:product, name: 'Solylent Green', product_version: 3, catalogue: catalogue) }
  let(:process) do
    pro = create(:aker_process, name: 'Baking')
    create(:aker_product_process, product: product, aker_process: pro, stage: 0)
    pro
  end
  let(:process_options) do
    product.processes.map do |pro|
      pro.process_modules.map(&:id)
    end
  end
  let(:project) { make_node('Operation Wolf', 'S1001', 41, 40, false, true, SecureRandom.uuid) }
  let(:subproject) { make_node('Operation Thunderbolt', 'S1001-0', 42, project.id, true, false, nil) }

  let(:plan) { create(:work_plan, project_id: subproject.id, product: product, comment: 'hello', desired_date: '2020-01-01') }

  def make_node(name, cost_code, id, parent_id, is_sub, is_proj, data_release_uuid)
    node = double('node',
                  name: name,
                  cost_code: cost_code,
                  id: id,
                  parent_id: parent_id,
                  subproject?: is_sub,
                  project?: is_proj,
                  node_uuid: make_uuid,
                  data_release_uuid: data_release_uuid)
    allow(StudyClient::Node).to receive(:find).with(node.id).and_return([node])
    node
  end  

  def make_uuid
    SecureRandom.uuid
  end

  def make_set(size = 6)
    uuid = make_uuid
    a_set = double(:set, uuid: uuid, id: uuid, meta: { 'size' => size }, locked: false)
    allow(SetClient::Set).to receive(:find).with(a_set.uuid).and_return([a_set])
    a_set
  end

  def make_barcode
    @barcode_index ||= 0
    @barcode_index += 1
    "AKER-#{@barcode_index}"
  end

  def make_container(materials)
    slots = materials.each_with_index.map do |mat, i|
      double('slot', material_id: mat&.id, address: "A:#{i + 1}")
    end
    double('container', barcode: make_barcode,
                        num_of_rows: 1,
                        num_of_cols: materials.length,
                        slots: slots)
  end

  def make_set_with_materials
    @set = make_set

    make_materials
    allow(@set).to receive(:materials).and_return(@materials)
    allow(SetClient::Set).to receive(:find_with_materials).with(@set.uuid).and_return([@set])
    @set
  end

  def make_result_set(items)
    rs = double('result_set', has_next?: false, length: items.length, to_a: items)
    allow(rs).to receive(:map) { |&block| items.map(&block) }
    allow(rs).to receive(:each) { |&block| items.each(&block) }
    allow(rs).to receive(:all?) { |&block| items.all?(&block) }
    double('result_set_wrapper', result_set: rs)
  end

  def make_materials
    @materials = (1..3).map do |i|
      attributes = {
        'gender' => i.even? ? 'male' : 'female',
        'donor_id' => "donor #{i}",
        'phenotype' => "phenotype #{i}",
        'scientific_name' => 'Mouse',
        'available' => true
      }
      double(:material, id: make_uuid, attributes: attributes)
    end
    allow(MatconClient::Material).to receive(:where) do |args|
      ids = args['_id']['$in']
      found = ids.map do |id|
        @materials.find { |m| m.id == id }
      end
      make_result_set(found)
    end
    @materials
  end

  context '#validation' do
    it 'fails to create a job if there is no work order specified' do
      expect{create :job, work_order: nil}.to raise_exception
    end
  end
  context '#status' do
    let(:job) { create :job}

    it 'checks when the jobs is queued' do
      expect(job.queued?).to eq(true)
      expect(job.active?).to eq(false)
      expect(job.cancelled?).to eq(false)
      expect(job.completed?).to eq(false)
    end

    it 'checks when the job is active?' do
      job.update_attributes(started: Time.now)
      expect(job.queued?).to eq(false)
      expect(job.active?).to eq(true)
      expect(job.cancelled?).to eq(false)
      expect(job.completed?).to eq(false)      
    end

    it 'checks when the job is completed?' do
      job.update_attributes(completed: Time.now)
      expect(job.queued?).to eq(false)
      expect(job.active?).to eq(false)
      expect(job.cancelled?).to eq(false)
      expect(job.completed?).to eq(true)      
    end

    it 'checks when the job is cancelled?' do
      job.update_attributes(cancelled: Time.now)
      expect(job.queued?).to eq(false)
      expect(job.active?).to eq(false)
      expect(job.cancelled?).to eq(true)
      expect(job.completed?).to eq(false)      
    end
  end

  describe "#lims_data" do

    def make_container(materials)
      slots = materials.each_with_index.map do |material,i|
        double('slot', material_id: material&.id, address: (i + 1).to_s)
      end
      @container = double('container',
                          id: make_uuid,
                          barcode: make_barcode,
                          num_of_rows: 1,
                          num_of_cols: materials.length,
                          slots: slots)


      allow(MatconClient::Container).to receive(:find).with(@container.id).and_return(@container)
      allow(MatconClient::Material).to receive(:where).with("_id" => {"$in" => job.material_ids }).and_return(materials)
      
      allow(MatconClient::Container).to receive(:where) do |args|
        material_ids = args['slots.material']['$in']
        containers = []
        if @container.slots.any? { |slot| material_ids.include? slot.material_id }
          containers = [@container]
        end
        make_result_set(containers)
      end
      @container
    end

    let(:order) do
      create(:work_order, process_id: process.id, work_plan: plan, set_uuid: @set.id, order_index: 0)
    end

    let(:modules) do
      (1...3).map { |i| create(:aker_process_module, name: "Module#{i}", aker_process_id: process.id) }
    end

    let(:job) do
      create(:job, work_order: order, container_uuid: @container.id)
    end

    before do
      make_set_with_materials
      make_container(@materials)
      modules.each_with_index { |m,i| WorkOrderModuleChoice.create(work_order: order, process_module: m, position: i)}
    end

    it "should return the lims_data" do
      data = job.lims_data[:job]
      expect(data[:process_name]).to eq(process.name)
      expect(data[:process_uuid]).to eq(process.uuid)
      expect(data[:work_order_id]).to eq(order.id)
      expect(data[:comment]).to eq(plan.comment)
      expect(data[:project_uuid]).to eq(project.node_uuid)
      expect(data[:project_name]).to eq(project.name)
      expect(data[:data_release_uuid]).to eq(project.data_release_uuid)
      expect(data[:cost_code]).to eq(project.cost_code)
      expect(data).not_to have_key(:desired_date)
      expect(data[:modules]).to eq(["Module1", "Module2"])
      material_data = data[:materials]
      expect(material_data.length).to eq(@materials.length)
      expect(data[:container]).to eq(
                                    container_id: @container.id,
                                    barcode: @container.barcode,
                                    num_of_rows: @container.num_of_rows,
                                    num_of_cols: @container.num_of_cols)

      @materials.zip(material_data).each do |mat, dat|
        slot = @container.slots.find { |the_slot| the_slot.material_id == mat.id }
        expect(dat[:_id]).to eq(mat.id)
        expect(dat[:address]).to eq(slot.address)
        expect(dat[:gender]).to eq(mat.attributes['gender'])
        expect(dat[:donor_id]).to eq(mat.attributes['donor_id'])
        expect(dat[:phenotype]).to eq(mat.attributes['phenotype'])
        expect(dat[:scientific_name]).to eq(mat.attributes['scientific_name'])
      end
    end

  end

end