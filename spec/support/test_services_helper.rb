module TestServicesHelper
  
  def webmock_containers_schema
    @container_schema = %Q{
      {"required": ["num_of_cols", "num_of_rows", "col_is_alpha", "row_is_alpha"], "type": "object", "properties": {"num_of_cols": {"max": 9999, "col_alpha_range": true, "required": true, "type": "integer", "min": 1}, "barcode": {"non_aker_barcode": true, "minlength": 6, "unique": true, "type": "string"}, "num_of_rows": {"row_alpha_range": true, "max": 9999, "required": true, "type": "integer", "min": 1}, "col_is_alpha": {"required": true, "type": "boolean"}, "print_count": {"max": 9999, "required": false, "type": "integer", "min": 0}, "row_is_alpha": {"required": true, "type": "boolean"}, "slots": {"uniqueaddresses": true, "type": "list", "schema": {"type": "dict", "schema": {"material": {"type": "uuid", "data_relation": {"field": "_id", "resource": "materials", "embeddable": true}}, "address": {"type": "string", "address": true}}}}}}
    }

    stub_request(:get, "http://localhost:5000/containers/json_schema").
         to_return(status: 200, body: @container_schema, headers: {})    
  end

  def webmock_materials_schema
    @material_schema = %Q{
      {"required": ["gender", "donor_id", "phenotype", "supplier_name", "common_name"], "type": "object", "properties": {"gender": {"required": true, "type": "string", "enum": ["male", "female", "unknown"]}, "date_of_receipt": {"type": "string", "format": "date"}, "material_type": {"enum": ["blood", "dna"], "type": "string"}, "donor_id": {"required": true, "type": "string"}, "phenotype": {"required": true, "type": "string"}, "supplier_name": {"required": true, "type": "string"}, "common_name": {"required": true, "type": "string", "enum": ["Homo Sapiens", "Mouse"]}, "parents": {"type": "list", "schema": {"type": "uuid", "data_relation": {"field": "_id", "resource": "materials", "embeddable": true}}}, "owner_id": {"type": "string"}}}
    }
    stub_request(:get, "http://localhost:5000/materials/json_patch_schema").
        to_return(status: 200, body: @material_schema, headers: {})

    stub_request(:get, "http://localhost:5000/materials/json_schema").
        to_return(status: 200, body: @material_schema, headers: {})

  end

  def webmock_matcon_schema
    webmock_materials_schema
    webmock_containers_schema
  end

  def make_work_order
    @work_order = instance_double("work_order", user: instance_double("user", email: "any"))
  end

  def made_up_uuid
    SecureRandom.uuid
  end

  def made_up_barcode
    @barcode_counter += 1
    "AKER-#{@barcode_counter}"
  end


  def make_material
    mat= double('material', id: made_up_uuid)
    allow(mat).to receive(:first).and_return(mat)
    mat
  end

  def make_container
    container = instance_double("container", slots: make_slots, barcode: made_up_barcode, id: made_up_uuid)
    allow(container).to receive(:material_id=)
    allow(container).to receive(:save)
    container
  end

  def stub_matcon
    stub_matcon_material
    stub_matcon_container
  end

  def stub_matcon_container
    @containers = []

    allow(MatconClient::Container).to receive(:destroy).and_return(true)

    allow(MatconClient::Container).to receive(:create) do |args|
      [args].flatten.map do
        container = make_container
        @containers.push(container)
        container
      end
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
    @materials = []

    allow(MatconClient::Material).to receive(:destroy).and_return(true)

    allow(MatconClient::Material).to receive(:create) do |args|
      @materials.concat!(materials_to_be_created(args))
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

