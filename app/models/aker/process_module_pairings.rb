# frozen_string_literal: true

module Aker
  class ProcessModulePairings < ApplicationRecord
    belongs_to :aker_process, class_name: 'Aker::Process', required: true
    validate :not_an_empty_pairing
    belongs_to :from_step, class_name: 'Aker::ProcessModule', optional: true
    belongs_to :to_step, class_name: 'Aker::ProcessModule', optional: true

    def not_an_empty_pairing
      return unless from_step_id.nil? && to_step_id.nil?
      errors[:base] << 'A pairing cannot have nil in both from_step and to_step at the same time'
    end
  end
end
