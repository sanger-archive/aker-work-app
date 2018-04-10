module WorkOrdersHelper
  def make_uuid
    SecureRandom.uuid
  end  

  def make_barcode
    @barcode_index ||= 0
    @barcode_index += 1
    "AKER-#{@barcode_index}"
  end

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

  def build_materials
    materials = (1..3).map do |i|
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
        materials.find { |m| m.id == id }
      end
      make_result_set(found)
    end
    materials    
  end

  def make_materials
    @materials = build_materials
  end

  def make_result_set(items)
    rs = double('result_set', has_next?: false, length: items.length, to_a: items)
    allow(rs).to receive(:map) { |&block| items.map(&block) }
    allow(rs).to receive(:each) { |&block| items.each(&block) }
    allow(rs).to receive(:all?) { |&block| items.all?(&block) }
    double('result_set_wrapper', result_set: rs)
  end  

  def build_set_with_materials
    set = make_set

    materials = build_materials
    allow(set).to receive(:materials).and_return(materials)
    allow(SetClient::Set).to receive(:find_with_materials).with(set.uuid).and_return([set])
    set    
  end

  def build_set_from_materials(materials)
    set = make_set

    allow(set).to receive(:materials).and_return(materials)
    allow(SetClient::Set).to receive(:find_with_materials).with(set.uuid).and_return([set])
    set    
  end


  def make_set_with_materials
    @set = build_set_with_materials
    @materials = @set.materials
    @set
  end

  def make_set(size = 6)
    uuid = make_uuid
    a_set = double(:set, uuid: uuid, id: uuid, meta: { 'size' => size }, locked: false)
    allow(SetClient::Set).to receive(:find).with(a_set.uuid).and_return([a_set])
    a_set
  end

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


  def make_processes(n)
    pros = (0...n).map { |i| create(:aker_process, name: "process #{i}") }
    pros.each_with_index { |pro, i| create(:aker_product_process, product: product, aker_process: pro, stage: i) }
    i = 0
    pros.each do |pro|
      (0...3).each do
        Aker::ProcessModule.create!(name: "module-#{i}", aker_process_id: pro.id)
        i += 1
      end
    end
    pros
  end

end