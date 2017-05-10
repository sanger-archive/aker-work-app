@javascript

Feature: Create an order

Because I want to order to do some work in some set of materials I am interested in
And I want to provide some instructions about how I want my petition to happen
But I also want to know in advance how much is going to cost me depending on my options

Background:

Given I am logged in as user "test@test"
And a set is defined

Scenario:

Given I go to the work order main page
And I click on "Create New Work Order"
Then I should see "Select Set"

When I choose "testing-set-1"
And I click on "Next"
Then show me the page
