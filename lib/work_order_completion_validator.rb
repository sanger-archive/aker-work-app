class WorkOrderCompletionValidator
  def self.validate(hash)
    JSON::Validator.fully_validate(Rails.configuration.work_order_completion_json_schema_path.to_s, hash)
  end
end