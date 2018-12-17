class ProcessModuleChoice < ApplicationRecord
  belongs_to :work_plan, required: true
  belongs_to :aker_process, class_name: 'Aker::Process', foreign_key: 'aker_process_id', required: true
  belongs_to :process_module, class_name: 'Aker::ProcessModule', foreign_key: 'aker_process_module_id', required: true

  validate :validate_selected_value
  validates :position, presence: true

  def description
    process_module.name + selected_value_description
  end

  def validate_selected_value
    min = process_module&.min_value
    max = process_module&.max_value

    return unless (min || max)

    if !selected_value
      errors.add(:selected_value, "The selected value is missing.")
    elsif min && selected_value < min
      errors.add(:selected_value, "The selected value is less than the minimum specified for this module.")
    elsif max && selected_value > max
      errors.add(:selected_value, "The selected value is greater than the maximum specified for this module.")
    end
  end

private

  def selected_value_description
    if process_module.min_value || process_module.max_value
      "(#{selected_value})"
    else
      ""
    end
  end
end
