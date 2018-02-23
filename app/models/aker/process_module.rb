class Aker::ProcessModule < ApplicationRecord
  validates :name, presence: true

  belongs_to :aker_process, class_name: "Aker::Process", required: true

  def to_custom_hash
    {name: name, id: id.to_s}
  end
end