class Aker::ProcessModule < ApplicationRecord
  belongs_to :aker_process, class_name: "Aker::Process"
end