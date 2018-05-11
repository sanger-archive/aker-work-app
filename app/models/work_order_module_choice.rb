class WorkOrderModuleChoice < ActiveRecord::Base
  validate :selected_value_is_right
  belongs_to :work_order, required: true
  belongs_to :process_module, class_name: 'Aker::ProcessModule', foreign_key: 'aker_process_modules_id'

  def description
     "#{process_module.name}#{selected_value_description}"
  end

  def selected_value_description
    requires_selected_value? ? " (#{selected_value})" : ""
  end

  def requires_selected_value?
    process_module.min_value || process_module.max_value
  end

  def selected_value_is_right
    if requires_selected_value?
      if !selected_value
        errors.add(:selected_value, 'The selected value does not have a valid value')
      end
    end
    if process_module.min_value
      if selected_value < process_module.min_value
        errors.add(:selected_value, 'The selected value is lower thant the minimum specified for the process module')
      end
    end
    if process_module.max_value
      if selected_value > process_module.max_value
        errors.add(:selected_value, 'The selected value is higher thant the maximum specified for the process module')
      end
    end
  end
end
