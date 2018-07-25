# frozen_string_literal: true

FactoryBot.define do
  lims_id = 'the LIMS'

  factory :catalogue do
    lims_id lims_id
    url 'someurl'
  end

  factory :catalogue_json, class: Hash do
    initialize_with do
      {}.merge(
        'catalogue': {
          'id': '1',
          'lims_id': lims_id,
          'url': 'http://mylims',
          'pipeline': 'a pipeline',
          'products': [{
            'catalogue_id': '1',
            'name': 'Cake',
            'description': 'delicious',
            'availability': 'available'
          }]
        }
      )
    end
  end
end
