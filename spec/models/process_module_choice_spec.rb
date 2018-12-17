require 'rails_helper'

RSpec.describe ProcessModuleChoice, type: :model do
  let(:plan) { create(:work_plan) }
  let(:pro) { create(:aker_process) }
  let(:mod) { create(:process_module, name: 'MyModule') }

  def choice_with_value(value)
    build(:process_module_choice, process_module: mod, aker_process: pro, work_plan: plan, selected_value: value, position: 1)
  end

  describe 'value validation' do
    context 'when the process module has upper and lower bounds' do
      let(:mod) { create(:process_module, min_value: 5, max_value: 10) }

      it 'is not valid if it is missing a value' do
        expect(choice_with_value(nil)).not_to be_valid
      end

      it 'is not valid if its value is too high' do
        expect(choice_with_value(11)).not_to be_valid
      end

      it 'is not valid if its value is too low' do
        expect(choice_with_value(4)).not_to be_valid
      end

      it 'is valid if the value is between the bounds' do
        expect(choice_with_value(8)).to be_valid
      end
    end

    context 'when the process module has a lower bound' do
      let(:mod) { create(:process_module, min_value: 5) }

      it 'is not valid if it is missing a value' do
        expect(choice_with_value(nil)).not_to be_valid
      end

      it 'is not valid if its value is too low' do
        expect(choice_with_value(4)).not_to be_valid
      end

      it 'is valid if the value is above the lower bound' do
        expect(choice_with_value(8)).to be_valid
      end

      it 'is valid if the value is equal to the lower bound' do
        expect(choice_with_value(5)).to be_valid
      end
    end

    context 'when the process module has an upper bound' do
      let(:mod) { create(:process_module, max_value: 10) }
      it 'is not valid if it is missing a value' do
        expect(choice_with_value(nil)).not_to be_valid
      end

      it 'is not valid if its value is too high' do
        expect(choice_with_value(11)).not_to be_valid
      end

      it 'is valid if the value is below the upper bound' do
        expect(choice_with_value(8)).to be_valid
      end

      it 'is valid if the value is equal to the upper bound' do
        expect(choice_with_value(10)).to be_valid
      end
    end

    context 'when the process module has no value bounds' do
      it 'is valid without a value' do
        expect(choice_with_value(nil)).to be_valid
      end
    end
  end

  describe 'presence validation' do
    it 'is not valid without a work plan' do
      expect(build(:process_module_choice, process_module: mod, aker_process: pro, work_plan: nil, position: 5)).not_to be_valid
    end
    it 'is not valid without a process' do
      expect(build(:process_module_choice, process_module: mod, aker_process: nil, work_plan: plan, position: 5)).not_to be_valid
    end
    it 'is not valid without a module' do
      expect(build(:process_module_choice, process_module: nil, aker_process: pro, work_plan: plan, position: 5)).not_to be_valid
    end
    it 'is not valid without a position' do
      expect(build(:process_module_choice, process_module: mod, aker_process: pro, work_plan: plan, position: nil)).not_to be_valid
    end
    it 'is valid with all the things it needs' do
      expect(build(:process_module_choice, process_module: mod, aker_process: pro, work_plan: plan, position: 5)).to be_valid
    end
  end

  describe '#description' do
    context 'when the choice has no selected value' do
      it 'should be equal to the module name' do
        expect(choice_with_value(nil).description).to eq(mod.name)
      end
    end

    context 'when the choice has a selected value' do
      let(:mod) { create(:process_module, name: 'MyModule', min_value: 5) }
      it 'should comprise the module name and the value' do
        expect(choice_with_value(14).description).to eq("#{mod.name}(14)")
      end
    end
  end
end
