module TestServicesHelper

  def allow_set_service_lock_set
    double_set = double('Aker::Set', id: 1)
    allow(SetClient::Set).to receive(:create).and_return(double_set)
    allow(double_set).to receive(:set_materials)
    allow(double_set).to receive(:update_attributes)
  end

  def webmock_containers_schema
    @container_schema = %Q{
      {"required": ["num_of_cols", "num_of_rows", "col_is_alpha", "row_is_alpha"], "type": "object", "properties": {"num_of_cols": {"max": 9999, "col_alpha_range": true, "required": true, "type": "integer", "min": 1}, "barcode": {"non_aker_barcode": true, "minlength": 6, "unique": true, "type": "string"}, "num_of_rows": {"row_alpha_range": true, "max": 9999, "required": true, "type": "integer", "min": 1}, "col_is_alpha": {"required": true, "type": "boolean"}, "print_count": {"max": 9999, "required": false, "type": "integer", "min": 0}, "row_is_alpha": {"required": true, "type": "boolean"}, "slots": {"uniqueaddresses": true, "type": "list", "schema": {"type": "dict", "schema": {"material": {"type": "uuid", "data_relation": {"field": "_id", "resource": "materials", "embeddable": true}}, "address": {"type": "string", "address": true}}}}}}
    }

    stub_request(:get, "#{Rails.configuration.material_url}containers/json_schema").
         to_return(status: 200, body: @container_schema, headers: {})
  end

  def webmock_materials_schema
    @material_schema = %Q{
      {"required": ["gender", "donor_id", "phenotype", "supplier_name", "scientific_name"], "type": "object", "properties": {"gender": {"required": true, "type": "string", "enum": ["male", "female", "unknown"]}, "date_of_receipt": {"type": "string", "format": "date"}, "material_type": {"enum": ["blood", "dna"], "type": "string"}, "donor_id": {"required": true, "type": "string"}, "phenotype": {"required": true, "type": "string"}, "supplier_name": {"required": true, "type": "string"}, "scientific_name": {"required": true, "type": "string", "enum": ["Homo Sapiens", "Mouse"]}, "parents": {"type": "list", "schema": {"type": "uuid", "data_relation": {"field": "_id", "resource": "materials", "embeddable": true}}}, "owner_id": {"type": "string"}}}
    }
    stub_request(:get, "#{Rails.configuration.material_url}materials/json_patch_schema").
        to_return(status: 200, body: @material_schema, headers: {})

    stub_request(:get, "#{Rails.configuration.material_url}materials/json_schema").
        to_return(status: 200, body: @material_schema, headers: {})

    stub_request(:get, "#{Rails.configuration.material_url}materials/schema").
        to_return(status: 200, body: @material_schema, headers: {})
  end

  def webmock_matcon_schema
    webmock_materials_schema
    webmock_containers_schema
  end

  def make_work_order
    @work_order = instance_double("work_order", user: instance_double("user", email: "any"), id: made_up_id)
  end

  def make_active_work_order
    work_order = instance_double("work_order", status: 'active',
      comment: 'any comment old',
      close_comment: nil,
      user: instance_double("user", email: "user@here.com"))
  end

  def made_up_set
    headers = {'Accept'=>'application/vnd.api+json', 'Content-Type'=>'application/vnd.api+json'}
    set_uuid = made_up_uuid
    set = double(:set, id: set_uuid, type: 'sets', name: 'A set name', owner_id: nil, locked: true, meta: { size: 1 })


    materials = 5.times.map{make_material}

    allow(set).to receive(:materials).and_return(materials)

    result = double('response')
    result_set = double('result_set')

    allow(result).to receive(:result_set).and_return(result_set)

    WorkOrder.any_instance.stub(:all_results).and_return(materials)

    allow(MatconClient::Material).to receive(:where).with("_id" => {"$in" => materials.map(&:id)}).and_return(result)
    allow(SetClient::Set).to receive(:find_with_materials).with(set_uuid).and_return([set])

    empty_response = double('result_set', result_set: nil)
    allow(MatconClient::Container).to receive(:where).and_return(empty_response)

    set
  end

  def made_up_uuid
    SecureRandom.uuid
  end

  def made_up_id
    @id_counter += 1
  end

  def made_up_barcode
    @barcode_counter += 1
    "AKER-#{@barcode_counter}"
  end


  def make_material
    mat= double('material', id: made_up_uuid, available: true)

    allow(mat).to receive(:attributes).and_return({'id'=> mat.id, 'available'=> mat.available})
    allow(mat).to receive(:first).and_return(mat)
    mat
  end

  def make_container
    container = instance_double("container", slots: make_slots, barcode: made_up_barcode, id: made_up_uuid)
    allow(container).to receive(:material_id=)
    allow(container).to receive(:save)
    container
  end

  def made_up_proposal
    prop = double('proposal', name: 'a name', cost_code: 'a cost code', id: 1)

    allow(StudyClient::Node).to receive(:find).with(prop.id).and_return([prop])

    prop
  end

  def stub_matcon
    stub_matcon_material
    stub_matcon_container
  end

  def stub_matcon_container
    @containers = []

    allow(MatconClient::Container).to receive(:destroy).and_return(true)

    allow(MatconClient::Container).to receive(:create) do |args|
      containers = [args].flatten.map do
        container = make_container
        @containers.push(container)
        container
      end
      instance_double('result_set', has_next?: false, first: containers.first, to_a: containers)
    end    
  end

  def materials_to_be_created(args)
    @stored_materials_created ||= {}
    [args].flatten.map do |arg|
      @stored_materials_created[arg] ||= make_material
    end
  end

  def stub_matcon_material
    @barcode_counter = 0
    @id_counter = 0
    @materials = []

    allow(MatconClient::Material).to receive(:destroy).and_return(true)

    allow(MatconClient::Material).to receive(:create) do |args|
      [args].flatten.map do
        material = make_material
        @materials.push(material)
        material
      end
    end
  end

  def make_slots
    'A:1 A:2 A:3 B:1 B:2 B:3'.split.map do |address|
      slot = double('slot', address: address)
      allow(slot).to receive(:material_id=)
      allow(slot).to receive(:material_id)
      slot
    end
  end


end

