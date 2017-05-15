@javascript

Feature: Create an order

Because I want to order to do some work in some set of materials I am interested in
And I want to provide some instructions about how I want my petition to happen
But I also want to know in advance how much is going to cost me depending on my options

Background:

Given I am logged in as user "test@test"

And the following sets are defined for user "test@test":
| Name          | Size |
| testing_set_1 | 3    |
| testing_set_2 | 5    |

Given a LIMS named "flimsy" at url "http://flimsy" has the following catalogue ready for send:

| Name           | Description | Version | Cost | Available? | Material Type | TAT |
| product_test_1 | A test      | 1       | 11   | available  | Cells         | 14  |
| product_test_2 | A test      | 2       | 22   | available  | Cells         | 10  |

Given the following proposals have been defined:
| Name       | Code  |
| Proposal 1 | 1     |
| Proposal 2 | 2     |

Scenario: Receiving a catalogue

When the LIMS "flimsy" send me the catalogue
Then I should have received the catalogue from the LIMS "flimsy" correctly

Scenario: Create a work order

Given I already received the catalogue from LIMS "flimsy"
When I go to the work order main page
And I click on "Create New Work Order"

Then I should see "Select Set"
And I should see "testing_set_1"
And I should see "testing_set_2"

When I choose "testing_set_1"
And I click on "Next"

Then I should see "Select Product"
And I should see "product_test_1"
And I should see "product_test_2"

When I choose "product_test_1"
And I click on "Next"

Then I should see "Cost summary"
And I should see "Total : £33.00"

When I click on "Next"

Then I should see "Select Proposal"
And I should see "Proposal 1"
And I should see "Proposal 2"

When I choose "Proposal 1"
And I click on "Next"

Then I should see "Confirm Order"
And I should see "testing_set_1"
And I should see "product_test_1"
And I should see "Proposal 1"
And I should see "£33.00"

When I save the order

Then I should see "Your work order has been created"

