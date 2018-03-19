class Aker::Process < ApplicationRecord
  validates :name, :TAT, :uuid, presence: true

  has_many :product_processes, foreign_key: :aker_process_id, dependent: :destroy
  has_many :process_modules, foreign_key: :aker_process_id, dependent: :destroy
  has_many :products, through: :product_processes

  enum process_class: { dna_sequencing: 0, genotyping: 1, transcriptomics: 2, cell_line_creation: 3 }

  def process_class_human
    return 'No product class set' if process_class.nil?
    self.class.process_class_to_human(process_class)
  end

  def self.process_class_translation
    I18n.t('.')[:activerecord][:attributes][:process][:process_class]
  end

  def self.human_to_process_class(text)
    process_class_translation.invert[text]
  end

  def self.process_class_to_human(process_class)
    process_class_translation[process_class.to_sym]
  end

  def build_available_links
    # create a hash, where the value is a list
    available_links = Hash.new{|h,k| h[k] = [] }
    pairings = Aker::ProcessModulePairings.where(aker_process_id: id)

    pairings.each do |pmp|
      from_step = pmp.from_step_id ? Aker::ProcessModule.find(pmp.from_step_id) : nil
      to_step = pmp.to_step_id ? Aker::ProcessModule.find(pmp.to_step_id) : nil

      if from_step.nil?
        available_links['start'] << to_step.to_custom_hash
      elsif to_step.nil?
        available_links[from_step.name] << { name: 'end'}
      else
        available_links[from_step.name] << to_step.to_custom_hash
      end
    end
    available_links
  end

  def build_default_path
    pairings = Aker::ProcessModulePairings.where(aker_process_id: id)
    default_path_ids = []

    start = pairings.where(from_step_id: nil, default_path: true)
    # assuming there is only one starting link
    default_path_ids << start[0].to_step_id

    default_path_list = pairings.where(default_path: true)
    # default_path_list.length-1 as we dont want to include the final nil to_step
    until default_path_ids.length == default_path_list.length-1
      next_module = Aker::ProcessModulePairings.where(from_step_id: default_path_ids.last, default_path: true)
      default_path_ids << next_module[0].to_step_id unless next_module[0].to_step_id == nil
    end

    default_path_ids.map {|id| Aker::ProcessModule.find(id).to_custom_hash }
  end
end