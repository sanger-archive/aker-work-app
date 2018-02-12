class Aker::ProcessModulePairings < ApplicationRecord
  belongs_to :aker_process, class_name: "Aker::Process", required: true
  # TODO: Ensure at least one of either from_step or to_step is required
  belongs_to :from_step, class_name: "Aker::ProcessModule", optional: true
  belongs_to :to_step, class_name: "Aker::ProcessModule", optional: true
end
