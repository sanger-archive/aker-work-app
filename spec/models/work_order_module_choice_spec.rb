require 'rails_helper'
RSpec.describe WorkOrderModuleChoice do
  let(:process) { create(:aker_process) }
  let(:work_order) { create :work_order }

  describe '#description' do
    let(:process_module) { create :aker_process_module, name: 'Process A', aker_process: process, min_value: 1, max_value: 99 }
    let(:choice) {
      create :work_order_module_choice, process_module: process_module, work_order: work_order, selected_value: 33
    }

    it 'displays the module name and the selected value' do
      expect(choice.description).to eq('Process A (33)')
    end

    context 'when there is no required selected value' do
      let(:process_module) { create :aker_process_module, name: 'Process A', aker_process: process, min_value: nil, max_value: nil }
      it 'does not display the selected value' do
        expect(choice.description).to eq('Process A')
      end

    end
  end

  describe '#validation' do

    context 'when the process module does not specify any value restrictions' do
      let(:process_module) { create :aker_process_module, aker_process: process }
      it 'is valid supplying a selected value' do
        choice = build :work_order_module_choice, process_module: process_module, work_order: work_order
        expect(choice.valid?).to eq(true)
      end
    end
    context 'when the process module specifies value restrictions' do
      context 'when it specifies a min value' do
        let(:process_module) { create :aker_process_module, aker_process: process, min_value: 44 }
        it 'is valid by supplying a selected value bigger than the min value' do
          choice = build :work_order_module_choice, process_module: process_module, work_order: work_order, selected_value: 45
          expect(choice.valid?).to eq(true)
        end
        it 'is not valid by supplying a selected value lower than the min value' do
          choice = build :work_order_module_choice, process_module: process_module, work_order: work_order, selected_value: 43
          expect(choice.valid?).to eq(false)
        end
        it 'is valid by specifying the min value as selected value' do
          choice = build :work_order_module_choice, process_module: process_module, work_order: work_order, selected_value: 44
          expect(choice.valid?).to eq(true)
        end
      end
      context 'when it specifies a max value' do
        let(:process_module) { create :aker_process_module, aker_process: process, max_value: 44 }
        it 'is not valid by supplying a selected value bigger than the max value' do
          choice = build :work_order_module_choice, process_module: process_module, work_order: work_order, selected_value: 45
          expect(choice.valid?).to eq(false)
        end
        it 'is valid by supplying a selected value lower than the max value' do
          choice = build :work_order_module_choice, process_module: process_module, work_order: work_order, selected_value: 43
          expect(choice.valid?).to eq(true)
        end
        it 'is valid by specifying the max value as selected value' do
          choice = build :work_order_module_choice, process_module: process_module, work_order: work_order, selected_value: 44
          expect(choice.valid?).to eq(true)
        end
      end

      context 'when it specifies both min and max value' do
        let(:process_module) { create :aker_process_module, aker_process: process, min_value: 42, max_value: 44 }
        it 'is not valid by supplying a selected value bigger than the max value' do
          choice = build :work_order_module_choice, process_module: process_module, work_order: work_order, selected_value: 45
          expect(choice.valid?).to eq(false)
        end
        it 'is not valid by supplying a selected value lower than the min value' do
          choice = build :work_order_module_choice, process_module: process_module, work_order: work_order, selected_value: 41
          expect(choice.valid?).to eq(false)
        end
        it 'is valid by supplying a selected value between the min and the max' do
          choice = build :work_order_module_choice, process_module: process_module, work_order: work_order, selected_value: 43
          expect(choice.valid?).to eq(true)
        end
        it 'is valid by specifying the min value as selected value' do
          choice = build :work_order_module_choice, process_module: process_module, work_order: work_order, selected_value: 42
          expect(choice.valid?).to eq(true)
        end
        it 'is valid by specifying the max value as selected value' do
          choice = build :work_order_module_choice, process_module: process_module, work_order: work_order, selected_value: 44
          expect(choice.valid?).to eq(true)
        end
      end

    end

  end

end