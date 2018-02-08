class Aker::ProcessModule < ApplicationRecord
  validates :name, presence: true

  belongs_to :aker_process, class_name: "Aker::Process", required: true
end