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
        pp["product_class"] = Product.human_product_class_to_symbol(pp["product_class"] )
        accepted_product_keys = ["name", "description", "product_version", "availability", "requested_biomaterial_type", "product_class", "external_id"]

        product = Product.create!(pp.select { |k,v| (accepted_product_keys.include?(k)) }.merge({ catalogue_id: catalogue.id }))

        pp["processes"].each do |p|
          p["external_id"] = p.delete "id"
          accepted_process_keys = ["name", "TAT", "external_id"]
          p.select { |k,v| (accepted_process_keys.include?(k)) }
          process = Aker::Process.create!(p.select { |k,v| (accepted_process_keys.include?(k)) })

          Aker::ProductProcess.create!(product_id: product.id, aker_process_id: process.id, stage: p["stage"])

          p["process_module_pairings"].each do |pm|
            Aker::ProcessModule.create!(name: pm["to_step"], aker_process_id: process.id)

            from_module = Aker::ProcessModule.find_by(name: pm["from_step"], aker_process_id: process.id) || Aker::NullProcessModule.new
            to_module = Aker::ProcessModule.find_by(name: pm["to_step"], aker_process_id: process.id) || Aker::NullProcessModule.new

            pm["external_id"] = pm.delete "id"
            Aker::ProcessModulePairings.create!(to_step: to_module, from_step: from_module,
              default_path: pm["default_path"], aker_process_id: process.id, external_id: pm["external_id"])
          end

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
end
