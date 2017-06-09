Feature: Complete a Work Order

In order to update the status of the work performed in the lab related to a set of biomaterials and containers
a LIMS wants to tell the work order application that a work order has been completed

Background:

Given I have a biomaterials service running
And I have a RabbitMQ server running

Scenario: Completing a Work Order

Given I created a work order "work_order"
And I process the work order "work_order" with the LIMS
When I send a completion message from the LIMS to the work order application

Then the work order "work_order" should be completed
And I should have published an event

Scenario: Completing a Work Order

Given I created a work order "work_order"
And I process the work order "work_order" with the LIMS

When I send a cancel message from the LIMS to the work order application

Then the work order "work_order" should be cancelled
And I should have published an event

