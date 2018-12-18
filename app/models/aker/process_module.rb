# frozen_string_literal: true

module Aker
  class ProcessModule < ApplicationRecord
    validates :name, presence: true

    belongs_to :aker_process, class_name: 'Aker::Process', required: true

    def to_custom_hash
      { name: name, id: id, min_value: min_value, max_value: max_value }
    end

    def accepts_value(value)
      return false if min_value.present? && (!value.present? || value < min_value)
      return false if max_value.present? && (!value.present? || value > max_value)
      true
    end
  end
end
