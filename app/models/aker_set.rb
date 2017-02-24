require 'set_service_client'

# Don't call it "Set", because that is a built-in type.
class AkerSet
    include ActiveModel::Model

    attr_accessor :uuid, :name, :locked
    alias_attribute :id, :uuid
    alias_method :locked?, :locked

    def self.new_from_json(data)
        new(uuid: data['id'],
            name: data['attributes']['name'],
            locked: data['attributes']['locked'])
    end

    def self.find(uuid)
        new_from_json(SetServiceClient::get_set(uuid)['data'])
    end

    def self.all
        SetServiceClient::get_all['data'].map {|data| new_from_json(data)}
    end

    def create_locked_clone(new_name)
        clone_uuid = SetServiceClient::clone_set(uuid, new_name)['data']['id']
        AkerSet.new_from_json(SetServiceClient::lock_set(clone_uuid)['data'])
    end

end
