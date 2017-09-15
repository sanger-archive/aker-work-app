Given(/^I am logged in as user "([^"]*)"$/) do |username|
  user = User.find_or_create_by(email: username)
  visit '/users/sign_in'
  fill_in "user_email", with: user.email
  fill_in "user_password", with: ''
  click_on "Log in"
end

Given(/^the following sets are defined for user "([^"]*)":$/) do |user, table|
  @sets_for_user ||= {}
  @sets_for_user[user] ||= []
  table.hashes.each do |myset|
    uuid = SecureRandom.uuid
    materials = myset['Size'].to_i.times.map do |i|
      material_uuid = SecureRandom.uuid
      material_obj = {"scientific_name"=>"Test", "donor_id"=>"Test", "gender"=>"Test",
        "phenotype"=>"Test", "supplier_name"=>"Test"}

      stub_request(:get, "#{Rails.configuration.material_url}/materials/#{material_uuid}").
         with(:headers => {'Content-Type'=>'application/json'}).
         to_return(:status => 200, :body => material_obj.to_json, :headers => {'Content-Type'=>'application/json'})

      { id: material_uuid, type: "materials" }
    end

    defined_set = {
      id: "#{uuid}",
      type: "sets",
      relationships: {
        materials: {
          links: {
            "self"=> "http://external-server:3000/api/v1/sets/#{uuid}/relationships/materials",
            related: "http://external-server:3000/api/v1/sets/#{uuid}"},
            data: materials
          }
      },
      meta: {
        size: myset['Size'].to_i
      },
      data: materials,
      materials: materials,
      included: materials,
      attributes: {
        name: myset['Name'],
        created_at: DateTime.now.to_s
      }
    }
    @sets_for_user[user].push(defined_set)
  end
  response_headers = {'Content-Type'=>'application/vnd.api+json'}

  stub_request(:get, "http://external-server:3000/api/v1/sets?filter%5Bowner_id%5D=#{user}&sort=-created_at").
    with(headers: {'Accept'=>'application/vnd.api+json'}).
    to_return(status: 200, body: {data: @sets_for_user[user], size: @sets_for_user[user].size}.to_json,
      headers: response_headers)

  @sets_for_user[user].each_with_index do |defined_set, index|
    uuid = defined_set[:id]
    stub_request(:get, "http://external-server:3000/api/v1/sets/#{uuid}").
      with(headers: {'Accept'=>'application/vnd.api+json'}).
      to_return(status: 200, body: {data: defined_set }.to_json,
        headers: response_headers)

    stub_request(:get, "http://external-server:3000/api/v1/sets/#{uuid}?include=materials").
      with(headers: {'Accept'=>'application/vnd.api+json'}).
      to_return(status: 200, body: {data: defined_set }.to_json,
        headers: response_headers)


    stub_request(:post, "http://external-server:3000/api/v1/sets/#{uuid}/clone").
      with(body: {data: {attributes: {name: "Work order #{index+1}"}}}.to_json,
           headers: {'Accept'=>'application/vnd.api+json'}).
      to_return(status: 200, body: {data: defined_set }.to_json,  headers: response_headers)

    stub_request(:patch, "http://external-server:3000/api/v1/sets/#{uuid}").
      with(body: {data: {id: uuid, type: 'sets', attributes: { locked: true}}}.to_json,
           headers: {'Accept'=>'application/vnd.api+json'}).
      to_return(status: 200, body: {data: defined_set }.to_json, headers: response_headers)

  end
end

Given(/^a set named "([^"]*)" of \d* elements is defined$/) do |set_name, size_set|
  @uuid = SecureRandom.uuid
  @set_instance = { id: "#{@uuid}", meta: { size: size_set}, attributes: {name: set_name }}
  response_headers = {'Content-Type'=>'application/vnd.api+json'}
  stub_request(:get, "http://external-server:3000/api/v1/sets?filter%5Bowner_id%5D=test@test").
    with(headers: {'Accept'=>'application/vnd.api+json'}).
    to_return(status: 200, body: {data: [@set_instance], size: size_set}.to_json,
      headers: response_headers)

  stub_request(:get, "http://external-server:3000/api/v1/sets/#{@uuid}").
    with(headers: {'Accept'=>'application/vnd.api+json'}).
    to_return(status: 200, body: {data: @set_instance }.to_json,
      headers: response_headers)

  stub_request(:post, "http://external-server:3000/api/v1/sets/#{@uuid}/clone").
    with(body: {data: {attributes: {name: "Work order 1"}}}.to_json,
         headers: {'Accept'=>'application/vnd.api+json'}).
    to_return(status: 200, body: {data: @set_instance }.to_json,  headers: response_headers)

  stub_request(:patch, "http://external-server:3000/api/v1/sets/#{@uuid}").
    with(body: {data: {id: @uuid, type: 'sets', attributes: { locked: true }}}.to_json,
         headers: {'Accept'=>'application/vnd.api+json'}).
    to_return(status: 200, body: {data: @set_instance }.to_json,  headers: response_headers)
end

Given(/^I go to the work order main page$/) do
  visit '/'
end

Given(/^I click on "([^"]*)"$/) do |text|
  click_on(text)
end

Then(/^show me the page$/) do
  save_and_open_page
end

Then(/^I should see "([^"]*)"$/) do |text|
  expect(page.has_content?(text)).to eq(true)
end

Then(/^I should not see "([^"]*)"$/) do |text|
  expect(page.has_content?(text)).to eq(false)
end

When(/^I choose "([^"]*)"$/) do |text|
  choose(text)
end

When(/^I choose "([^"]*)" in a table$/) do |text|
  page.find('tr', text: text).find('input').click
end

Given(/^the following proposals have been defined:$/) do |table|
  response_headers = {'Content-Type'=>'application/vnd.api+json'}
  @proposals ||= []
  table.hashes.each_with_index do |proposal, index|
    node_template = {type: "nodes", attributes: { id: index, node_uuid: SecureRandom.uuid, name: proposal['Name'], "cost-code".to_sym => proposal['Code']}}

    stub_request(:get, "http://external-server:3300/api/v1/nodes/nodes/#{index}").
      with(headers: {'Accept'=>'application/vnd.api+json'}).
      to_return(status: 200, body: {data: node_template }.to_json,
        headers: response_headers)

    @proposals.push(node_template)
  end

  @all_proposals = @proposals.map do |p|
    if p[:attributes][:'cost-code']
      p[:attributes][:cost_code] = p[:attributes].delete(:'cost-code')
    end
    proposal = double('StudyClient::Node', p[:attributes])
    allow(StudyClient::Node).to receive(:find).with(p[:attributes][:id]).and_return([proposal])
    proposal
  end
  allow_any_instance_of(OrdersController).to receive(:get_all_proposals_spendable_by_current_user).and_return(@all_proposals)

  stub_request(:get, "http://external-server:3300/api/v1/nodes/nodes?filter%5Bcost_code%5D=!_none").
    with(headers: {'Accept'=>'application/vnd.api+json'}).
    to_return(status: 200, body: {data: @proposals}.to_json, headers: response_headers)
end

Given (/^the user "([^"]*)" has permission "([^"]*)" for the materials in the set "([^"]*)"$/) do |email, role, set_name|
  my_set = @sets_for_user[email].select{|s| s[:attributes][:name] == set_name}.first
  my_set = double('set', my_set)
  allow(SetClient::Set).to receive(:find_with_materials).with(my_set.id).and_return([my_set])
  materials = 5.times.map{ double('material', id: SecureRandom.uuid)}
  allow(my_set).to receive(:materials).and_return(materials)
  allow(StampClient::Permission).to receive(:check_catch).and_return(true)
  allow(StampClient::Permission).to receive(:unpermitted_uuids).and_return([])
end

Given(/^the user "([^"]*)" has permission "([^"]*)" for the proposal "([^"]*)"$/) do |email, role, proposal_name|
  allow(StudyClient::Node).to receive(:authorize!) do |role_param, proposal_param, email_param|
    value = false
    if role_param == role.to_sym && email_param.include?(email)
      proposal = @all_proposals.select{|p| p.name == proposal_name}.first

      value = true if proposal_param.to_s == proposal.id.to_s
    end
    raise CanCan::AccessDenied.new('Not Authorized!') unless value
    value
  end
end

Given(/^a LIMS named "([^"]*)" at url "([^"]*)" has the following catalogue ready for send:$/) do |lims_name, lims_url, table|
  @catalogues ||= {}
  products = []
  table.hashes.each do |product|
    mapping = {'Name' => 'name', 'Description' => 'description', 'Version' => 'product_version',
      'Availability' => 'availability',
      'Material Type' => 'requested_biomaterial_type', 'TAT' => 'TAT', 'Product Class' => 'product_class'}
    products.push(product.keys.reduce({}) {|memo, key| memo[mapping[key]] = product[key] ; memo })
  end
  @catalogues[lims_name] = {catalogue: {products: products, url: lims_url}}
end

When(/^the LIMS "([^"]*)" send me the catalogue$/) do |lims_name|
  post catalogue_path, @catalogues[lims_name]
end

Then(/^I should have received the catalogue from the LIMS "([^"]*)" correctly/) do |lims_name|
  expect(@catalogues[lims_name][:catalogue][:products].all? do |p|
    !Product.find_by(name: p["name"]).nil?
  end).to eq(true)
end

Given(/^I already received the catalogue from LIMS "([^"]*)"/) do |lims_name|
  steps(<<-GHERKIN)
    When the LIMS "#{lims_name}" send me the catalogue
    Then I should have received the catalogue from the LIMS "#{lims_name}" correctly
  GHERKIN
end

Given(/^I save the order$/) do
  WorkOrder.any_instance.stub(:send_to_lims).and_return(true)
  step('I click on "Save & Exit"')
end

Given(/^I have a RabbitMQ server running$/) do
  # We add a spy to the publish method for EventService to check it later
  allow(EventService).to receive(:publish)
end

Given(/^I have a biomaterials service running$/) do
    @material_schema = %Q{
      {"required": ["gender", "donor_id", "phenotype", "supplier_name", "scientific_name"], "type": "object", "properties": {"gender": {"required": true, "type": "string", "enum": ["male", "female", "unknown"]}, "date_of_receipt": {"type": "string", "format": "date"}, "material_type": {"enum": ["blood", "dna"], "type": "string"}, "donor_id": {"required": true, "type": "string"}, "phenotype": {"required": true, "type": "string"}, "supplier_name": {"required": true, "type": "string"}, "scientific_name": {"required": true, "type": "string", "enum": ["Homo Sapiens", "Mouse"]}, "parents": {"type": "list", "schema": {"type": "uuid", "data_relation": {"field": "_id", "resource": "materials", "embeddable": true}}}, "owner_id": {"type": "string"}}}
    }

    @container_schema = %Q{
      {"required": ["num_of_cols", "num_of_rows", "col_is_alpha", "row_is_alpha"], "type": "object", "properties": {"num_of_cols": {"max": 9999, "col_alpha_range": true, "required": true, "type": "integer", "min": 1}, "barcode": {"non_aker_barcode": true, "minlength": 6, "unique": true, "type": "string"}, "num_of_rows": {"row_alpha_range": true, "max": 9999, "required": true, "type": "integer", "min": 1}, "col_is_alpha": {"required": true, "type": "boolean"}, "print_count": {"max": 9999, "required": false, "type": "integer", "min": 0}, "row_is_alpha": {"required": true, "type": "boolean"}, "slots": {"uniqueaddresses": true, "type": "list", "schema": {"type": "dict", "schema": {"material": {"type": "uuid", "data_relation": {"field": "_id", "resource": "materials", "embeddable": true}}, "address": {"type": "string", "address": true}}}}}}
    }

    stub_request(:get, "#{Rails.configuration.material_url}materials/json_schema").
         to_return(status: 200, body: @material_schema, headers: {})

    stub_request(:get, "#{Rails.configuration.material_url}materials/schema").
         to_return(status: 200, body: @material_schema, headers: {})

    stub_request(:get, "#{Rails.configuration.material_url}containers/json_schema").
         to_return(status: 200, body: @container_schema, headers: {})

    stub_request(:get, "#{Rails.configuration.material_url}materials/json_patch_schema").
        to_return(status: 200, body: @material_schema, headers: {})
end

Given(/^I created a work order "([^"]*)"$/) do |arg1|
    @work_order = FactoryGirl.create(:work_order)
end

Given(/^I process the work order "([^"]*)" with the LIMS/) do |arg1|
  @work_order.update_attributes(status: WorkOrder.ACTIVE)
end

Given(/^my set contents materials are all available$/) do
  allow_any_instance_of(UpdateOrderService).to receive(:check_set_contents).and_return(true)
end

When(/^I send a completion message from the LIMS to the work order application$/) do
  step('I prepare for a finish message')

  @work_order_completion_msg = FactoryGirl.build(:valid_work_order_completion_message_json)
  @work_order_completion_msg[:work_order][:work_order_id]=@work_order.id

  header "HTTP_ACCEPT", "application/json"
  header "CONTENT_TYPE", "application/json"

  post complete_path(@work_order), @work_order_completion_msg.to_json
end

When(/^I send a cancel message from the LIMS to the work order application$/) do
  step('I prepare for a finish message')

  @work_order_completion_msg = FactoryGirl.build(:valid_work_order_completion_message_json)
  @work_order_completion_msg[:work_order][:work_order_id]=@work_order.id

  header "HTTP_ACCEPT", "application/json"
  header "CONTENT_TYPE", "application/json"

  post cancel_path(@work_order), @work_order_completion_msg.to_json
end

When(/^I prepare for a finish message$/) do
  set_double = double("set")
  allow(set_double).to receive(:id)
  allow(set_double).to receive(:set_materials)
  allow(set_double).to receive(:update_attributes)

  allow(SetClient::Set).to receive(:create).and_return(set_double)
end

Then(/^I should have received a finish message$/) do
  expect(EventService).to have_received(:publish)
end

Then(/^the work order "([^"]*)" should be completed$/) do |arg1|
  @work_order.reload
  expect(@work_order.status).to eq(WorkOrder.COMPLETED)
end

Then(/^the work order "([^"]*)" should be cancelled$/) do |arg1|
  @work_order.reload
  expect(@work_order.status).to eq(WorkOrder.CANCELLED)
end

Then(/^I should have published an event$/) do
  expect(EventService).to have_received(:publish)
end
