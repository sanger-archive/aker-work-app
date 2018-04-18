# Aker - Work Orders

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

* [Product catalogue schema](https://ssg-confluence.internal.sanger.ac.uk/display/PSDPUB/Product+catalogue#Productcatalogue-Schema)
* [Product catalogue messages](https://ssg-confluence.internal.sanger.ac.uk/display/PSDPUB/Messages#Messages-Productcataloguemessages)
* [Work order messages](https://ssg-confluence.internal.sanger.ac.uk/display/PSDPUB/Messages#Messages-Workordermessages)

# Misc.
## Assets
Assets are now compiled on the environments and do not need to be committed with the project
anymore.
