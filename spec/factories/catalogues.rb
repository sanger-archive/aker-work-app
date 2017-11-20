FactoryGirl.define do
  factory :catalogue do
    lims_id 'my lims'
  end

  factory :catalogue_json, class: Hash do |catalogue|
    initialize_with { Hash.new.merge({
        "catalogue": {
          "id": "1",
          "lims_id": "my new lims",
          "url": "http://mylims",
          "pipeline": "a pipeline",
          "products": [{
            "catalogue_id": "1",
            "name": "Cake",
            "description": "delicious",
            "availability": "available"
          }]
        }
      })
    }
  end

end
