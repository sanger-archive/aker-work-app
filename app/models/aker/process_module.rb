class Aker::ProcessModule < ApplicationRecord
  validates :name, presence: true, uniqueness: { scope: :aker_process,
    message: "should have unique module names per aker process" }

  belongs_to :aker_process, class_name: "Aker::Process", required: true
end