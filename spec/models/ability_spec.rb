require 'rails_helper'

RSpec.describe Ability, type: :model do
  describe '#permitted?' do

    context 'when the permission type is :read' do
      let(:user) { OpenStruct.new(email: 'user@here', groups: []) }
      let(:plan) { create(:work_plan) }
      let(:ability) { Ability.new(user) }

      it 'the user should be permitted' do
        expect(ability.permitted?(plan, user, :read)).to eq(true)
      end
    end

    context 'when the permission type is :create' do
      let(:user) { OpenStruct.new(email: 'user@here', groups: []) }
      let(:plan) { create(:work_plan) }
      let(:ability) { Ability.new(user) }

      it 'the user should be permitted' do
        expect(ability.permitted?(plan, user, :create)).to eq(true)
      end
    end

    context 'when the permission type is :write' do
      let(:user) { OpenStruct.new(email: 'user@here', groups: []) }
      let(:plan) { create(:work_plan) }
      let(:ability) { Ability.new(user) }

      context 'when the user is permitted' do
        before do
          allow(plan).to receive(:user_permitted?).and_return(true)
        end

        it 'the user should be permitted' do
          expect(ability.permitted?(plan, user, :write)).to eq(true)
        end
      end

      context 'when the user is not permitted' do
        before do
          allow(plan).to receive(:user_permitted?).and_return(false)
        end

        it 'the user should not be permitted' do
          expect(ability.permitted?(plan, user, :write)).to eq(false)
        end
      end
    end

  end
end
