class Aker::ProductProcess < ApplicationRecord
  belongs_to :product
  belongs_to :aker_process, class_name: "Aker::Process"
end