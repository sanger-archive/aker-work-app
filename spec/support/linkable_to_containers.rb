require 'spec_helper'

RSpec.shared_examples "linkable_to_containers" do |attributes|

  let(:container) { double("MatconClient::Container", uuid: SecureRandom.uuid) }
  let(:model) { create(model_name) }
  let(:decorated_model) { model.decorate }

  # For the name of the methods, assume the attribute passed is "container_uuid"
  attributes.each do |attribute|

    describe "Link #{attribute} to Container" do

      before do
        @stripped_attribute = attribute.to_s.sub(/_uuid/, '')
      end

      describe '#container' do

        let(:model) { build(model_name, "#{attribute}": container.uuid) }

        before do
          stub_request(:get, "http://external-server:5000/containers/#{container.uuid}")
            .to_return(status: 200, body: file_fixture("container.json"), headers: { 'Content-Type': 'application/json' })

          stub_request(:get, "http://external-server:5000/containers/json_schema")
            .to_return(status: 200, body: file_fixture("container_schema.json").read, headers: { 'Content-Type' => 'application/json' })
        end

        it 'returns the Container' do
          expect(decorated_model.send(@stripped_attribute)).to be_instance_of MatconClient::Container
        end

      end

      describe '#container=' do

        before do
          decorated_model.send("#{@stripped_attribute}=", container)
        end

        it 'sets container_uuid to container.uuid' do
          expect(decorated_model.send(attribute)).to eql(container.uuid)
        end

        it 'sets the @container instance variable' do
          expect(decorated_model.send(@stripped_attribute)).to eq(container)
        end

      end
    end
  end

end