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
      material_obj = {"common_name"=>"Test", "donor_id"=>"Test", "gender"=>"Test", 
        "phenotype"=>"Test", "supplier_name"=>"Test"}

      stub_request(:get, "#{Rails.configuration.material_url}/materials/#{material_uuid}").
         with(:headers => {'Content-Type'=>'application/json'}).
         to_return(:status => 200, :body => material_obj.to_json, :headers => {'Content-Type'=>'application/json'})

      { id: material_uuid, type: "materials" }
    end

    @sets_for_user[user].push(
      { 
        id: "#{uuid}",
        type: "sets",
        relationships: { materials: { links: { 
          "self"=> "http://external-server:3000/api/v1/sets/#{uuid}/relationships/materials", 
          related: "http://external-server:3000/api/v1/sets/#{uuid}"}, 
          data: materials} },
        meta: { size: myset['Size'].to_i }, 
        data: materials,
        materials: materials,
        included: materials,        
        attributes: { name: myset['Name']  }
      }
    )
  end
  response_headers = {'Content-Type'=>'application/vnd.api+json'}
  
  stub_request(:get, "http://external-server:3000/api/v1/sets?filter%5Bowner_id%5D=#{user}").
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
      to_return(status: 200, body: {data: defined_set }.to_json,  headers: response_headers)        
  end
end

Given(/^a set named "([^"]*)" of \d* elements is defined$/) do |set_name, size_set|
  @uuid = SecureRandom.uuid
  @set_instance = { id: "#{@uuid}", meta: { size: size_set}, attributes: {name: set_name}}
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
    with(body: {data: {id: @uuid, type: 'sets', attributes: { locked: true}}}.to_json,
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


When(/^I choose "([^"]*)"$/) do |text|
  choose(text)
end

Given(/^the following proposals have been defined:$/) do |table|
  response_headers = {'Content-Type'=>'application/vnd.api+json'}
  @proposals ||= []
  table.hashes.each_with_index do |proposal, index|
    uuid = SecureRandom.uuid
    node_template = {type: "nodes", attributes: { id: uuid, name: proposal['Name'], "cost-code".to_sym => proposal['Code']}}
    set_template = { id: uuid, meta: { size: 1}, attributes: {name: proposal['Name']}}

    @proposals.push(node_template)

    stub_request(:get, "http://external-server:3300/api/v1/nodes/nodes/#{uuid}"). 
      with(headers: {'Accept'=>'application/vnd.api+json'}).
      to_return(status: 200, body: {data: node_template }.to_json, 
        headers: response_headers)
    stub_request(:get, "http://external-server:3000/api/v1/sets/#{uuid}").
      with(headers: {'Accept'=>'application/vnd.api+json'}).
      to_return(status: 200, body: {data: set_template }.to_json, 
        headers: response_headers)
  end

  stub_request(:get, "http://external-server:3300/api/v1/nodes/nodes?filter%5Bcost_code%5D=!_none").
    with(headers: {'Accept'=>'application/vnd.api+json'}).
    to_return(status: 200, body: {data: @proposals}.to_json, headers: response_headers)  
end

Given(/^a LIMS named "([^"]*)" at url "([^"]*)" has the following catalogue ready for send:$/) do |lims_name, lims_url, table|
  @catalogues ||= {}
  products = []
  table.hashes.each do |product|
    mapping = {'Name' => 'name', 'Description' => 'description', 'Version' => 'product_version', 
      'Cost' => 'cost_per_sample', 'Availability' => 'availability', 
      'Material Type' => 'requested_biomaterial_type', 'TAT' => 'TAT'}
    products.push(product.keys.reduce({}) {|memo, key| memo[mapping[key]] = product[key] ; memo })
  end
  @catalogues[lims_name] = {catalogue: {products: products, url: lims_url}}
end

When(/^the LIMS "([^"]*)" send me the catalogue$/) do |lims_name|
  post catalogues_path, @catalogues[lims_name]
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
