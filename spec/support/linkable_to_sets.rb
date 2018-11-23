require 'spec_helper'

RSpec.shared_examples "linkable_to_sets" do |attributes|

  let(:set) { double("SetClient::Set", uuid: SecureRandom.uuid) }
  let(:container) { double("MatconClient::Container", uuid: SecureRandom.uuid) }
  let(:model) { create(model_name) }
  let(:decorated_model) { model.decorate }

  attributes.each do |attribute|

    describe "Link #{attribute} to Set" do

      before do
        @stripped_attribute = attribute.to_s.sub(/_uuid/, '')
      end

      describe "#set" do
        context "when #{attribute}? is false" do
          it 'is nil' do
            expect(decorated_model.send(@stripped_attribute)).to be_nil
          end
        end

        context "when #{attribute}? is true" do
          let(:model) { build(model_name, "#{attribute}": SecureRandom.uuid) }

          before :each do
            stub_request(:get, "http://external-server:3000/api/v1/sets/#{model.send(attribute)}")
              .to_return(status: 200, body: file_fixture("set.json"), headers: { 'Content-Type': 'application/vnd.api+json' })
          end

          it 'returns a SetClient::Set' do
            expect(decorated_model.send(@stripped_attribute)).to be_instance_of(SetClient::Set)
          end
        end
      end

      describe '#set=' do

        before do
          decorated_model.send("#{@stripped_attribute}=", set)
        end

        it 'sets set_uuid to set.uuid' do
          expect(decorated_model.send(attribute)).to eql(set.uuid)
        end

        it 'sets the @set instance variable' do
          expect(decorated_model.send(@stripped_attribute)).to eq(set)
        end

      end

      describe '#set_size' do

        let(:method_name) { "#{@stripped_attribute}_size"}

        context 'when Set has been set' do
          let(:set) { double("SetClient::Set", uuid: SecureRandom.uuid, meta: { 'size' => 96 }) }

          before :each do
            decorated_model.send("#{@stripped_attribute}=", set)
          end

          it 'returns the number of samples in #set' do
            expect(decorated_model.send(method_name)).to eql(96)
          end

        end

        context 'when set is not set' do
          it 'returns nil' do
            expect(decorated_model.send(method_name)).to be_nil
          end
        end

      end

      describe '#set_materials' do

        let(:method_name) { "#{@stripped_attribute}_materials" }

        before do
          stub_request(:get, "http://external-server:3000/api/v1/sets/#{set.uuid}?include=materials")
            .to_return(status: 200, body: file_fixture("set_with_materials.json"), headers: { 'Content-Type': 'application/vnd.api+json'})

          decorated_model.send("#{@stripped_attribute}=", set)
        end

        it 'returns the materials in #set' do
          expect(decorated_model.send(method_name)).to all be_instance_of SetClient::Material
        end

      end

      describe '#create_set' do

        let(:method_name) { "create_#{@stripped_attribute}"}

        before do
          stub_request(:post, "http://external-server:3000/api/v1/sets")
            .with(body: "{\"data\":{\"type\":\"sets\",\"attributes\":{\"name\":\"My Set\"}}}")
            .to_return(status: 201, body: file_fixture("set.json"), headers: { 'Content-Type': 'application/vnd.api+json'})

          decorated_model.send(method_name, name: 'My Set')
        end

        it 'assigns the new Set to #set' do
          expect(decorated_model.send(@stripped_attribute)).to be_instance_of(SetClient::Set)
        end

      end

      describe '#set_material_ids' do

        let(:method_name) { "#{@stripped_attribute}_material_ids" }

        before do
          stub_request(:get, "http://external-server:3000/api/v1/sets/#{set.uuid}?include=materials")
            .to_return(status: 200, body: file_fixture("set_with_materials.json"), headers: { 'Content-Type': 'application/vnd.api+json'})

          decorated_model.send("#{@stripped_attribute}=", set)
        end

        it 'returns the material_ids in #set' do
          material_ids = decorated_model.send(method_name)
          expect(material_ids).to be_instance_of Array
          expect(material_ids).to include("01cb5442-f7f1-4247-813e-8e7693b0b17d", "030a06d1-0309-4fb0-8c7f-571d5c8dcebc", "056ee9c0-0a9d-4213-bb68-0aacbc53653b", "06816dc3-f68e-4491-9b24-36a00e79133e", "082828d2-9635-4b7d-ba4c-46bddcb6692c")
        end

      end

      describe '#set_full_materials' do

        let(:method_name) { "#{@stripped_attribute}_full_materials" }

        before do
          stub_request(:get, "http://external-server:3000/api/v1/sets/#{set.uuid}?include=materials")
            .to_return(status: 200, body: file_fixture("set_with_materials.json"), headers: { 'Content-Type': 'application/vnd.api+json'})

          stub_request(:post, "http://external-server:5000/materials/search").
            with(
              body: "{\"where\":{\"_id\":{\"$in\":[\"01cb5442-f7f1-4247-813e-8e7693b0b17d\",\"030a06d1-0309-4fb0-8c7f-571d5c8dcebc\",\"056ee9c0-0a9d-4213-bb68-0aacbc53653b\",\"06816dc3-f68e-4491-9b24-36a00e79133e\",\"082828d2-9635-4b7d-ba4c-46bddcb6692c\"]}}}",
            )
            .to_return(status: 200, body: file_fixture("materials.json"), headers: { 'Content-Type': 'application/json' })

          stub_request(:get, "http://external-server:5000/materials/json_schema")
            .to_return(status: 200, body: file_fixture("material_schema.json"), headers: { 'Content-Type': 'application/json' })

          decorated_model.send("#{@stripped_attribute}=", set)
        end

        it 'returns the materials in #set from the Materials Service' do
          materials = decorated_model.send(method_name)
          expect(materials).to all be_instance_of MatconClient::Material
          expect(materials.map(&:id)).to include("01cb5442-f7f1-4247-813e-8e7693b0b17d", "030a06d1-0309-4fb0-8c7f-571d5c8dcebc", "056ee9c0-0a9d-4213-bb68-0aacbc53653b", "06816dc3-f68e-4491-9b24-36a00e79133e", "082828d2-9635-4b7d-ba4c-46bddcb6692c")
        end

      end

      describe '#set_containers' do

        let(:method_name) { "#{@stripped_attribute}_containers"}

        before do
          stub_request(:get, "http://external-server:3000/api/v1/sets/#{set.uuid}?include=materials")
            .to_return(status: 200, body: file_fixture("set_with_materials.json"), headers: { 'Content-Type': 'application/vnd.api+json'})

          stub_request(:post, "http://external-server:5000/containers/search")
            .with(
              body: "{\"where\":{\"slots.material\":{\"$in\":[\"01cb5442-f7f1-4247-813e-8e7693b0b17d\",\"030a06d1-0309-4fb0-8c7f-571d5c8dcebc\",\"056ee9c0-0a9d-4213-bb68-0aacbc53653b\",\"06816dc3-f68e-4491-9b24-36a00e79133e\",\"082828d2-9635-4b7d-ba4c-46bddcb6692c\"]}}}",
            )
            .to_return(status: 200, body: file_fixture("containers.json"), headers: { 'Content-Type' => 'application/json' })

          stub_request(:get, "http://external-server:5000/containers/json_schema")
            .to_return(status: 200, body: file_fixture("container_schema.json").read, headers: { 'Content-Type' => 'application/vnd.api+json' })

          decorated_model.send("#{@stripped_attribute}=", set)
        end

        it 'returns the containers for materials in #set from the Materials Service' do
          containers = decorated_model.send(method_name)
          expect(containers).to all be_instance_of MatconClient::Container
        end
      end

    end

  end

end