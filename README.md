# Aker - Work Orders

This application allows users to create and manage work orders.

# Setup
## Database
To create the databases for the dev environment: `rake db:setup`

## Broker
To create the exchanges, queues and usernames etc. use the GitLab repo: [aker-environments](https://gitlab.internal.sanger.ac.uk/aker/aker-environments)

# Testing
To run ALL the tests for this project: `bundle exec rake`

To run just the rspec tests: `bundle exec rspec`

# Misc.
## Assets
Note that if any changes are made in the `app/client`,`app/assets` or `app/javascript` directories,
any files in the `public/assets`,`public/packs` or `public/packs-test` directory must be removed,
and webpack must be run with the `webpack.production.js` configuration file:

    rm -r public/assets
    rm -r public/packs
    rm -r public/packs-test
    RAILS_ENV=test bundle exec rake assets:precompile
    RAILS_ENV=production bundle exec rake assets:precompile

## Messages
A list of available messages which can be used in Work Orders can be found [here](messages.md).
