class Aker::Process < ApplicationRecord
  validates :name, :TAT, presence: true
  validates :name, uniqueness: true

  has_many :product_processes, foreign_key: :aker_process_id, dependent: :destroy
  has_many :process_modules, foreign_key: :aker_process_id, dependent: :destroy
  has_many :products, through: :product_processes
end