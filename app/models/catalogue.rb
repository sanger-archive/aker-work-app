class Catalogue < ApplicationRecord

  has_many :products

  before_validation :sanitise_lims
  before_save :sanitise_lims

  validates :lims_id, presence: true

  def self.create_with_products(catalogue_params)
    catalogue = nil
    begin
      transaction do
        product_params = catalogue_params[:products]
        validate_module_names(product_params)

        lims_id = catalogue_params[:lims_id]
        where(lims_id: lims_id).update_all(current: false)

        accepted_catalogue_keys = %i[pipeline url lims_id]
        catalogue = create!(catalogue_params.select { |k, _v| accepted_catalogue_keys.include?(k) }.merge( current: true ))

        create_products(product_params, catalogue.id)
      end
    # rescue => ex
      # publish_event(catalogue_params, false, ex)
    # else
      # publish_event(catalogue_params, true)
    end
    catalogue
  end

  def self.create_products(products, catalogue_id)
    products.each do |pp|
      # Store ID from message as the external ID for the product
      pp[:external_id] = pp.delete :id

      accepted_product_keys = %i[name description product_version availability requested_biomaterial_type product_class external_id]
      product = Product.create!(pp.select { |k, _v| accepted_product_keys.include?(k) }.merge({ catalogue_id: catalogue_id }))

      create_processes(pp[:processes], product.id)
    end
  end

  def self.create_processes(processes, product_id)
    processes.each_with_index do |p, i|
      p[:external_id] = p.delete :id
      accepted_process_keys = %i[name TAT external_id]
      process = Aker::Process.create!(p.select { |k, _v| accepted_process_keys.include?(k) })
      # Stage is determined by the order each process appears in the array.
      # First stage is 1. I'm sorry.
      Aker::ProductProcess.create!(product_id: product_id, aker_process_id: process.id, stage: i + 1)

      create_process_modules(p[:process_module_pairings], process.id)
    end
  end

  def self.validate_module_names(product_params)
    module_names = product_params.map do |pp|
      pp[:processes].map do |pr|
        pr[:process_module_pairings].map do |pm|
          [pm[:to_step], pm[:from_step]]
        end
      end
    end .flatten.compact.uniq
    bad_modules = module_names.reject { |m| validate_module_name(m) }
    unless bad_modules.empty?
      raise "Process module could not be validated: #{bad_modules}"
    end
  end

  def self.create_process_modules(process_module_pairing, process_id)
    process_module_pairing.each do |pm|
      # Create the process module(s), if they don't already exist
      if pm[:to_step]
        to_module = Aker::ProcessModule.where(name: pm[:to_step], aker_process_id: process_id).first_or_create
      else
        to_module = nil
      end

      if pm[:from_step]
        from_module = Aker::ProcessModule.where(name: pm[:from_step], aker_process_id: process_id).first_or_create
      else
        from_module = nil
      end


      # Create the pairing represented by the current 'pm'
      Aker::ProcessModulePairings.create!(
        to_step: to_module,
        from_step: from_module,
        default_path: pm[:default_path],
        aker_process_id: process_id
      )
    end
  end

  # def self.publish_event(catalogue_params, valid, error_msg = nil)
  #   message = EventMessage.new(catalogue: catalogue_params.merge(valid: valid), error: error_msg)
  #   EventService.publish(message)
  # end

  def sanitise_lims
    return unless lims_id
    sanitised = lims_id.strip.gsub(/\s+/, ' ')
    self.lims_id = sanitised if sanitised != lims_id
  end

  def self.validate_module_name(module_name)
    uri_module_name = module_name.tr(' ', '_').downcase
    BillingFacadeClient.validate_process_module_name(uri_module_name)
  end
end
