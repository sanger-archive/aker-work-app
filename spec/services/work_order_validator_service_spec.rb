require 'rails_helper'

RSpec.describe WorkOrderValidatorService do
  before do
    @work_order = create :work_order, status: 'in progress'
    @msg = build :work_order_completion_message_json
    @msg[:work_order][:work_order_id] = @work_order.id
    @validator = WorkOrderValidatorService.new(@work_order, @msg)

    @work_order.stub(:has_materials?) { true }
    @validator.stub(:containers_has_changed?) { false }

    @material_schema = %Q{
      {"required": ["gender", "donor_id", "phenotype", "supplier_name", "common_name"], "type": "object", "properties": {"gender": {"required": true, "type": "string", "enum": ["male", "female", "unknown"]}, "date_of_receipt": {"type": "string", "format": "date"}, "material_type": {"enum": ["blood", "dna"], "type": "string"}, "donor_id": {"required": true, "type": "string"}, "phenotype": {"required": true, "type": "string"}, "supplier_name": {"required": true, "type": "string"}, "common_name": {"required": true, "type": "string", "enum": ["Homo Sapiens", "Mouse"]}, "parents": {"type": "list", "schema": {"type": "uuid", "data_relation": {"field": "_id", "resource": "materials", "embeddable": true}}}, "owner_id": {"type": "string"}}}                
    }

    @container_schema = %Q{
      {"required": ["num_of_cols", "num_of_rows", "col_is_alpha", "row_is_alpha"], "type": "object", "properties": {"num_of_cols": {"max": 9999, "col_alpha_range": true, "required": true, "type": "integer", "min": 1}, "barcode": {"non_aker_barcode": true, "minlength": 6, "unique": true, "type": "string"}, "num_of_rows": {"row_alpha_range": true, "max": 9999, "required": true, "type": "integer", "min": 1}, "col_is_alpha": {"required": true, "type": "boolean"}, "print_count": {"max": 9999, "required": false, "type": "integer", "min": 0}, "row_is_alpha": {"required": true, "type": "boolean"}, "slots": {"uniqueaddresses": true, "type": "list", "schema": {"type": "dict", "schema": {"material": {"type": "uuid", "data_relation": {"field": "_id", "resource": "materials", "embeddable": true}}, "address": {"type": "string", "address": true}}}}}}
    }

    stub_request(:get, "http://localhost:5000/materials/json_schema").
         to_return(status: 200, body: @material_schema, headers: {})    
    stub_request(:get, "http://localhost:5000/containers/json_schema").
         to_return(status: 200, body: @container_schema, headers: {})
  end

  describe "#validate?" do
    it "fails when the work order is not in the right status" do
      @work_order.status = 'completed'
      expect(@validator.validate?).to eq(false)
      expect(@validator.errors.empty?).to eq(false)
    end
    it "fails when the json schema validation is not valid" do
      @msg['extra_info']='another extra info'
      expect(@validator.validate?).to eq(false)
      expect(@validator.errors.empty?).to eq(false)
    end
    it "fails when the work order does not exists" do
      @msg[:work_order][:work_order_id] = -1 
      expect(@validator.validate?).to eq(false)
      expect(@validator.errors.empty?).to eq(false)
    end
    it "fails when the work order updated materials are not the same defined in the message" do
      @work_order.stub(:has_materials?) { false }
      expect(@validator.validate?).to eq(false)
      expect(@validator.errors.empty?).to eq(false)
    end
    it "fails when the containers have changed" do
      @validator.stub(:containers_has_changed?) { true }

      expect(@validator.validate?).to eq(false)
      expect(@validator.errors.empty?).to eq(false)
    end

    it "success when the data is right" do
      expect(@validator.validate?).to eq(true)
      expect(@validator.errors.empty?).to eq(true)
    end
  end
end
