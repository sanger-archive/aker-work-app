require 'spec_helper'

shared_examples_for "accessible" do
  let(:model) { described_class }

  describe 'Creation' do
    before do
      @model = create(model.to_s.underscore.to_sym)
    end

    it "gives the creator rw permission" do
      expect(@model.permitted?(@model.user.email, :r)).to be true
      expect(@model.permitted?(@model.user.email, :w)).to be true
    end

    it 'does not give another user rw permission' do
      user = build(:user)

      expect(@model.permitted?(user.email, :r)).to be false
      expect(@model.permitted?(user.email, :w)).to be false
    end

    it 'gives the group "world" read permission only' do
      expect(@model.permitted?('world', :r)).to be true
      expect(@model.permitted?('world', :w)).to be false
    end
  end
end