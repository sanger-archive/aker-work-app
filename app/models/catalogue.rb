class Catalogue < ApplicationRecord

  has_many :products

  before_validation :sanitise_lims
  before_save :sanitise_lims

  validates :lims_id, presence: true

  def self.create_with_products(catalogue_params)
  	catalogue = nil
  	transaction do
      lims_id = catalogue_params["lims_id"]
  		where(lims_id: lims_id).update_all(current: false)

      accepted_catalogue_keys = ['pipeline', 'url', 'lims_id']
      catalogue = create!(catalogue_params.select { |k,v| (accepted_catalogue_keys.include?(k)) }.merge({ current: true }))
  		product_params = catalogue_params['products']
      price_placeholder = 0

      create_products(product_params, catalogue.id)
  	end
  	catalogue
  end

  def self.create_products(products, catalogue_id)
    products.each do |pp|
      # Store ID from message as the external ID for the product
      pp["external_id"] = pp.delete "id"

      accepted_product_keys = ["name", "description", "product_version", "availability", "requested_biomaterial_type", "product_class", "external_id"]
      product = Product.create!(pp.select { |k,v| (accepted_product_keys.include?(k)) }.merge({ catalogue_id: catalogue_id }))

      create_processes(pp["processes"], product.id)
    end
  end

  def self.create_processes(processes, product_id)
    processes.each_with_index do |p, i|
      p["external_id"] = p.delete "id"
      accepted_process_keys = ["name", "TAT", "external_id"]
      p.select { |k,v| (accepted_process_keys.include?(k)) }
      process = Aker::Process.create!(p.select { |k,v| (accepted_process_keys.include?(k)) })
      # Stage is determined by the order each process appears in the array.
      # First stage is 1. I'm sorry.
      Aker::ProductProcess.create!(product_id: product_id, aker_process_id: process.id, stage: i + 1)

      create_process_modules(p["process_module_pairings"], process.id)
    end
  end

  def self.create_process_modules(process_module_pairing, process_id)
    process_module_pairing.each do |pm|
      # Create the process module(s), if they don't already exist
      unless pm["to_step"].nil?
        to_module = Aker::ProcessModule.where(name: pm["to_step"], aker_process_id: process_id).first_or_create
      end

      unless pm["from_step"].nil?
        from_module = Aker::ProcessModule.where(name: pm["from_step"], aker_process_id: process_id).first_or_create
      end

      # Create the pairing represented by the current 'pm'
      Aker::ProcessModulePairings.create!(to_step: to_module, from_step: from_module,
        default_path: pm["default_path"], aker_process_id: process_id)
    end
  end

  def sanitise_lims
    if lims_id
      sanitised = lims_id.strip.gsub(/\s+/,' ')
      if sanitised != lims_id
        self.lims_id = sanitised
      end
    end
  end
end
