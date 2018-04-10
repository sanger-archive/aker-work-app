RSpec::Matchers.define :match_api_schema do |schema|
  match do |response|
    schema_directory = "#{Dir.pwd}/spec/support/api/v1/schemas"
    schema_path = "#{schema_directory}/#{schema}.json"
    JSON::Validator.validate!(schema_path, response.body)
  end
end