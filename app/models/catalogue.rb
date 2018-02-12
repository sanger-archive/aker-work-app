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
      catalogue = create!(catalogue_params.select { |k,v| (accepted_catalogue_keys.include?(k)) }.merge({current: true}))
  		product_params = catalogue_params['products']
      price_placeholder = 0
  		product_params.each do |pp|
        # replace id key with external_id
        pp["external_id"] = pp.delete "id"
        # TODO: Figure out what's happening with this product_class stuff
        # pp["product_class"] = Product.human_product_class_to_symbol(pp["product_class"])
        accepted_product_keys = ["name", "description", "product_version", "availability", "requested_biomaterial_type", "product_class", "external_id"]

        product = Product.create!(pp.select { |k,v| (accepted_product_keys.include?(k)) }.merge({ catalogue_id: catalogue.id }))

        pp["processes"].each do |p|
          p["external_id"] = p.delete "id"
          accepted_process_keys = ["name", "TAT", "external_id"]
          p.select { |k,v| (accepted_process_keys.include?(k)) }
          process = Aker::Process.create!(p.select { |k,v| (accepted_process_keys.include?(k)) })
          Aker::ProductProcess.create!(product_id: product.id, aker_process_id: process.id, stage: p["stage"])
          create_process_module_pairings(p["process_module_pairings"], process.id)
        end
  		end
  	end
  	catalogue
  end

  def sanitise_lims
    if lims_id
      sanitised = lims_id.strip.gsub(/\s+/,' ')
      if sanitised != lims_id
        self.lims_id = sanitised
      end
    end
  end

  def self.create_process_module_pairings(process_modules, process_id)
    process_modules.each do |pm|
      unless pm["to_step"].nil?
        to_module = Aker::ProcessModule.where(name: pm["to_step"], aker_process_id: process_id).first_or_create
      end

      unless pm["from_step"].nil?
        from_module = Aker::ProcessModule.where(name: pm["from_step"], aker_process_id: process_id).first_or_create
      end

      pm["external_id"] = pm.delete "id"
      Aker::ProcessModulePairings.create!(to_step: to_module, from_step: from_module,
        default_path: pm["default_path"], aker_process_id: process_id, external_id: pm["external_id"])
    end
    puts "done!"
  end
end
