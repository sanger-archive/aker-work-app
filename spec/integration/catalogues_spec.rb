require 'swagger_helper'
require 'securerandom'

require 'support/test_services_helper'

describe 'Catalogues API' do
  include TestServicesHelper

  before do
    webmock_matcon_schema
    allow_set_service_lock_set
  end


  let(:catalogue) { build(:catalogue_json) }

  path '/api/v1/catalogue' do


    post 'Creates a new catalogue of products' do
      tags 'Catalogues'
      consumes 'application/json'
      produces 'application/json'



      parameter name: :catalogue, in: :body,  schema: { 
        type: :object, 
        properties: {
          catalogue: {
            type: :object,
            required: ['products'],
            properties: {
              url: {type: "string"}, 
              lims_id: {type: :string}, 
              pipeline: {type: :string},
              products: {
                type: :array, items: {
                  type: :object, properties: {
                    name: {type: :string},
                    product_version: {type: :integer},
                    description: {type: :string},
                    availability: {type: :string, enum: ['available','unavailable']},
                    TAT: {type: :integer},
                    requested_biomaterial_type: {type: :string},
                    product_class: {type: :string}
                  }
                }
              }
            }
          }
        }
      }
         
      response '201', 'catalogue created' do
        run_test!
      end

    end
  end

end
