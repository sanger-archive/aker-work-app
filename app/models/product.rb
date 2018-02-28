class Product < ApplicationRecord
  validates :catalogue_id, presence: true

  belongs_to :catalogue
  has_many :product_processes, foreign_key: :product_id, dependent: :destroy, class_name: "Aker::ProductProcess"
  has_many :processes, through: :product_processes, source: :aker_process

  enum product_class: { dna_sequencing: 0, genotyping: 1, transcriptomics: 2, cell_line_creation: 3 }

  def product_class_text
    return 'No product class set' if product_class.nil?
    self.class.product_class_symbol_to_human_product_class(product_class)
  end

  def self.human_product_class_to_symbol(human_product_class)
    I18n.t('.')[:activerecord][:attributes][:product][:product_class].invert[human_product_class]
  end

  def self.product_class_symbol_to_human_product_class(product_class_symbol)
    I18n.t("activerecord.attributes.#{model_name.i18n_key}.product_class.#{product_class_symbol}")
  end

  def build_available_links(pairings)
    # create a hash, where the value is a list
    available_links = Hash.new{|h,k| h[k] = [] }

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

  def build_default_path(pairings)
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

  def self.available
    Product.where(availability: true)
  end

  def self.suspended
    Product.where(availability: false)
  end

end
