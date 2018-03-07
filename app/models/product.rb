class Product < ApplicationRecord
  validates :catalogue_id, presence: true

  belongs_to :catalogue
  has_many :product_processes, -> { order(:stage) }, foreign_key: :product_id, dependent: :destroy, class_name: "Aker::ProductProcess"
  has_many :processes, -> { order('aker_product_processes.stage') }, through: :product_processes, source: :aker_process

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

  def self.available
    Product.where(availability: true)
  end

  def self.suspended
    Product.where(availability: false)
  end

  def available?
    self.availability
  end

  def suspended?
    !self.availability
  end

end
