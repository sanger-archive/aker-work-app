class Catalogue < ApplicationRecord

  has_many :products

  before_validation :sanitise_lims
  before_save :sanitise_lims

  validates :lims_id, presence: true

  def self.create_with_products(catalogue_params)
    catalogue = nil
    begin
      transaction do
        process_params = catalogue_params[:processes]
        product_params = catalogue_params[:products]
        validate_products(product_params)
        validate_processes(process_params, product_params)
        validate_module_names(process_params)

        lims_id = catalogue_params[:lims_id]
        where(lims_id: lims_id).update_all(current: false)

        accepted_catalogue_keys = %i[pipeline url lims_id]
        catalogue = create!(catalogue_params.select { |k, _v| accepted_catalogue_keys.include?(k) }.merge( current: true ))

        processes = create_processes(process_params)
        create_products(product_params, processes, catalogue.id)
      end
    end
    catalogue
  end

  def self.create_processes(process_params)
    process_params.each_with_index.map do |p, i|
      accepted_process_keys = %i[name TAT uuid process_class]
      process = Aker::Process.create!(p.select { |k, _v| accepted_process_keys.include?(k) })
      create_process_modules(p[:process_module_pairings], process.id)
      process
    end
  end

  def self.create_products(product_params, processes, catalogue_id)
    product_params.each do |pp|

      accepted_product_keys = %i[name description product_version availability requested_biomaterial_type uuid]
      product = Product.create!(pp.select { |k, _v| accepted_product_keys.include?(k) }.merge({ catalogue_id: catalogue_id }))

      pp[:process_uuids].each_with_index do |uuid, i|
        process = processes.find { |pro| pro.uuid==uuid }
        # Stage is determined by the order each process uuid appears in the array, starting at zero
        Aker::ProductProcess.create!(product_id: product.id, aker_process_id: process.id, stage: i)
      end
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

  def sanitise_lims
    return unless lims_id
    sanitised = lims_id.strip.gsub(/\s+/, ' ')
    self.lims_id = sanitised if sanitised != lims_id
  end

  def self.validate_module_names(process_params)
    module_names = process_params.map do |pp|
      pp[:process_module_pairings].map do |pm|
        [pm[:to_step], pm[:from_step]]
      end
    end .flatten.compact.uniq
    bad_modules = module_names.reject { |m| validate_module_name(m) }
    unless bad_modules.empty?
      raise "Process module could not be validated: #{bad_modules}"
    end
  end

  def self.validate_module_name(module_name)
    uri_module_name = module_name.tr(' ', '_').downcase
    BillingFacadeClient.validate_process_module_name(uri_module_name)
  end

  # All products must have a unique name and uuid (within the catalogue)
  def self.validate_products(product_params)
    product_uuids = product_params.map { |prod| prod[:uuid] }

    if product_uuids.any?(&:nil?)
      raise "Products listed in catalogue without uuids"
    end

    if product_uuids.uniq.size != product_uuids.size
      duplicates = product_uuids.select { |uuid| product_uuids.count(uuid) > 1 }.uniq
      raise "Duplicate product uuids specified: #{duplicates.uniq}"
    end

    product_names = product_params.map { |prod| prod[:name] }

    if product_names.any?(&:nil?)
      raise "Products listed in catalogue without names"
    end

    if product_names.uniq.size != product_names.size
      duplicates = product_names.select { |name| product_names.count(name) > 1 }.uniq
      raise "Duplicate product names specified: #{duplicates.uniq}"
    end
  end

  # All process must have unique uuids (within the catalogue).
  # All products must reference uuids of processes defined in this catalogue.
  def self.validate_processes(process_params, product_params)
    if process_params.nil?
      raise "Processes missing from catalogue data"
    end
    process_uuids = process_params.map { |pro| pro[:uuid] }
    if process_uuids.any?(&:nil?)
      raise "Processes are missing uuids"
    end
    if process_uuids.uniq.size != process_uuids.size
      duplicates = process_uuids.select { |uuid| process_uuids.count(uuid) > 1 }.uniq
      raise "Duplicate process uuids specified: #{duplicates.uniq}"
    end
    products_without_processes = []
    products_with_nonexistent_processes = []
    products_with_duplicate_processes = []
    product_params.each do |prod|
      pu = prod[:process_uuids]
      if pu.nil? || pu.empty?
        products_without_processes.push(prod[:name])
      elsif !(pu - process_uuids).empty?
        products_with_nonexistent_processes.push(prod[:name])
      elsif pu.uniq.size != pu.size
        products_with_duplicate_processes.push(prod[:name])
      end
    end
    unless products_without_processes.empty?
      raise "Products in catalogue specified without process uuids: #{products_without_processes}"
    end
    unless products_with_nonexistent_processes.empty?
      raise "Products listed with process uuids not defined in the catalogue: #{products_with_nonexistent_processes}"
    end
    unless products_with_duplicate_processes.empty?
      raise "Products in catalogue contain repeated process uuids: #{products_with_duplicate_processes}"
    end
  end
end




















