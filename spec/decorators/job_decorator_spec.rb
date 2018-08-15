# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobDecorator do

  let(:job) { create(:job) }
  let(:decorated_job) { job.decorate }
  let(:container) { double("MatconClient::Container", uuid: SecureRandom.uuid) }

  it_behaves_like "linkable_to_sets", [:input_set_uuid, :set_uuid] do
    let(:model_name) { :job }
  end

  it_behaves_like "linkable_to_containers", [:container_uuid] do
    let(:model_name) { :job }
  end

  describe 'delegation' do

    it 'delegates to the Job' do
      expect(decorated_job.started).to eql(job.started)
      expect(decorated_job.completed).to eql(job.completed)
      expect(decorated_job.close_comment).to eql(job.close_comment)
    end

  end

  describe '#work_order' do
    it 'returns a DecoratedWorkOrder' do
      expect(decorated_job.work_order).to be_instance_of WorkOrder
    end
  end

end