require 'rails_helper'
require 'support/work_orders_helper'

RSpec.describe 'Jobs', type: :model do
  include WorkOrdersHelper
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

  context '#material_ids' do

    it 'returns only the materials from the container that also belongs to the set work order' do
      # We create a group of materials
      set = build_set_with_materials
      
      # We divide it in 2 groups
      groups = []
      set.materials.each_with_index do |material, pos| 
        groups[pos % 2] = [] unless groups[pos % 2]
        groups[pos % 2].push(material)
      end

      # Gets half of the materials to create a set
      half_set = build_set_from_materials(groups[0])

      # Create a container that contains the total of materials
      make_container(set.materials)

      # Creates an order on half of the materials of the container
      order = create(:work_order, process_id: process.id, work_plan: plan, set_uuid: half_set.id, order_index: 0)

      # Job for the container
      job = create(:job, work_order: order, container_uuid: @container.id)
      
      # The materials of the job should be only the materials of the half set we created before, ignoring
      # other materials in the container
      expect(job.material_ids.length).to eq(half_set.materials.length)
    end
  end

  describe "#lims_data" do

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

      allow(MatconClient::Material).to receive(:where).with("_id" => {"$in" => job.material_ids }).and_return(@materials)
    end

    it "should return the lims_data" do
      data = job.lims_data[:job]
      expect(data[:job_id]).to eq(job.id)
      expect(data[:work_order_id]).to eq(job.work_order.id)
      expect(data[:process_name]).to eq(process.name)
      expect(data[:process_uuid]).to eq(process.uuid)
      expect(data[:work_order_id]).to eq(order.id)
      expect(data[:comment]).to eq(plan.comment)
      expect(data[:project_uuid]).to eq(subproject.node_uuid)
      expect(data[:project_name]).to eq(subproject.name)
      expect(data[:data_release_uuid]).to eq(subproject.data_release_uuid)
      expect(data[:cost_code]).to eq(subproject.cost_code)
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