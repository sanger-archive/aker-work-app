# Aker - Work App

[![Build Status](https://travis-ci.org/sanger/aker-work-app.svg?branch=devel)](https://travis-ci.org/sanger/aker-work-app)
[![Maintainability](https://api.codeclimate.com/v1/badges/d2721eface0c9cc74bb6/maintainability)](https://codeclimate.com/github/sanger/aker-work-app/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/d2721eface0c9cc74bb6/test_coverage)](https://codeclimate.com/github/sanger/aker-work-app/test_coverage)

This application allows users to create and manage work orders.

# Setup
## Database
To create the databases for your local environment: `bundle exec rails db:setup`

## JavaScript
Use Yarn to install the required Node modules: `bundle exec rails yarn:install`

## Broker
To create the exchanges, queues and usernames etc. use the GitLab repo: [aker-environments](https://gitlab.internal.sanger.ac.uk/aker/aker-environments)

# Testing
## Rspec
To run the rspec tests: `bundle exec rspec`

## JavaScript
To run JavaScript tests: `yarn test`

## Messages
The following messages are useful during testing:

* [Product catalogue schema](https://ssg-confluence.internal.sanger.ac.uk/display/PSDPUB/Product+Catalogue+JSON)
* [Product catalogue messages](https://ssg-confluence.internal.sanger.ac.uk/display/PSDPUB/Messages#Messages-Productcataloguemessages)
* [Work order messages](https://ssg-confluence.internal.sanger.ac.uk/display/PSDPUB/Messages#Messages-Workordermessages)

# Updates
## Gems
Run `bundle update` followed by `bundle exec rspec` to have the latest gems included in the project
and make sure that they behave as expected.

# Node packages
Run `yarn upgrade` follow by `yarn test`  to have the latest node packages included in the project
and make sure that they behave as expected.
# Misc.
## Assets
Assets are now compiled on the environments and do not need to be committed with the project
anymore.
