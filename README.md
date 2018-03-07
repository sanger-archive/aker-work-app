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
## Catalogue message
The following message can be used to create a catalogue but currently process names have to be
unique so adjust the message as required.
```json
{
  "catalogue": {
    "id": 1,
    "pipeline": "WGS",
    "url": "http://dev.psd.sanger.ac.uk:6600/api/v2/aker/work_orders",
    "lims_id": "SQSC",
    "products": [{
      "id": 2,
      "name": "QC",
      "description": "Lorem Ipsum",
      "product_version": 1,
      "availability": 1,
      "requested_biomaterial_type": "blood",
      "product_class": "genotyping",
      "processes": [{
        "id": 2,
        "name": "QC1",
        "stage": 1,
        "TAT": 5,
        "process_module_pairings": [{
            "from_step": null,
            "to_step": "Quantification",
            "default_path": true
          }, {
            "from_step": null,
            "to_step": "Genotyping CGP SNP",
            "default_path": false
          },
          {
            "from_step": null,
            "to_step": "Genotyping DDD SNP",
            "default_path": false
          }, {
            "from_step": null,
            "to_step": "Genotyping HumGen SNP",
            "default_path": false
          }, {
            "from_step": "Quantification",
            "to_step": null,
            "default_path": false
          }, {
            "from_step": "Genotyping CGP SNP",
            "to_step": null,
            "default_path": false
          }, {
            "from_step": "Genotyping DDD SNP",
            "to_step": null,
            "default_path": false
          },
          {
            "from_step": "Genotyping HumGen SNP",
            "to_step": null,
            "default_path": true
          }, {
            "from_step": "Quantification",
            "to_step": "Genotyping CGP SNP",
            "default_path": true
          }, {
            "from_step": "Quantification",
            "to_step": "Genotyping DDD SNP",
            "default_path": false
          },
          {
            "from_step": "Quantification",
            "to_step": "Genotyping HumGen SNP",
            "default_path": false
          }
        ]
      }]
    }]
  }
}
```
