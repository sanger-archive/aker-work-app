class Product < ApplicationRecord
  belongs_to :catalogue

  enum availability: { suspended: 0, available: 1 }
  enum product_class: { dna_sequencing: 0, genotyping: 1, transcriptomics: 2, cell_line_creation: 3 }

  def product_class_text
    self.class.product_class_symbol_to_human_product_class(product_class)
  end

  def availability_text
    I18n.t("activerecord.attributes.#{model_name.i18n_key}.availability.#{availability}")
  end

  def self.human_product_class_to_symbol(human_product_class)
    I18n.t('.')[:activerecord][:attributes][:product][:product_class].invert[human_product_class]
  end

  def self.product_class_symbol_to_human_product_class(product_class_symbol)
    I18n.t("activerecord.attributes.#{model_name.i18n_key}.product_class.#{product_class_symbol}")
  end  

  def self.product_class_symbol_to_human_product_class(product_class_symbol)
    I18n.t("activerecord.attributes.#{model_name.i18n_key}.product_class.#{product_class_symbol}")
  end
end
