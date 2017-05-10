Given(/^I am logged in as user "([^"]*)"$/) do |username|
  user = User.find_or_create_by(email: username)
  visit '/users/sign_in'
  fill_in "user_email", with: user.email
  fill_in "user_password", with: ''
  click_on "Log in"
end

Given(/^a set is defined$/) do
  @uuid = SecureRandom.uuid
  response_headers = {'Content-Type'=>'application/vnd.api+json'}
  stub_request(:get, "http://external-server:3000/api/v1/sets/sets?filter%5Bowner_id%5D=test@test").
    with(headers: {'Accept'=>'application/vnd.api+json'}).
    to_return(status: 200, body: {data: [{ id: "#{@uuid}", meta: { size: 1}, attributes: {name: "testing-set-1"}}], size: 1}.to_json, 
      headers: response_headers)  
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