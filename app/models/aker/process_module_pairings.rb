class Aker::ProcessModulePairings < ApplicationRecord
  belongs_to :aker_process, class_name: "Aker::Process", required: true
  belongs_to :from_step, class_name: "Aker::ProcessModule"
  belongs_to :to_step, class_name: "Aker::ProcessModule"

  def from_step
    super || Aker::NullProcessModule.new
  end

  def to_step
    super || Aker::NullProcessModule.new
  end

end