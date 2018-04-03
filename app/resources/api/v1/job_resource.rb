module Api
  module V1
    class JobResource < JSONAPI::Resource
      attributes :container_uuid, :work_order_id, :status, :started, :completed, :cancelled
    end
  end
end