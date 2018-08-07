require 'spec_helper'

RSpec.shared_examples "linkable_to_projects" do |attributes|

  let(:model) { create(model_name) }
  let(:decorated_model) { model.decorate }

  # For the test descriptions, assume the attribute is "project_id"
  attributes.each do |attribute|

    describe "Link #{attribute} to Container" do

      before do
        @stripped_attribute = attribute.to_s.sub(/_id/, '')
      end

      describe '#project' do
        context 'when project_id? is false' do
          it 'is nil' do
            expect(decorated_model.send(@stripped_attribute)).to be_nil
          end
        end

        context 'when project_id? is true' do
          let(:model) { build(model_name, project_id: 999) }

          before :each do
            stub_request(:get, "http://external-server:3300/api/v1/nodes/999")
              .to_return(status: 200, body: file_fixture('project.json'), headers: { 'Content-Type': 'application/vnd.api+json'})
          end

          it 'returns a StudyClient::Node' do
            expect(decorated_model.send(@stripped_attribute)).to be_instance_of(StudyClient::Node)
          end
        end

      end

    end
  end

end