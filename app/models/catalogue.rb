

class Catalogue < ApplicationRecord
  has_many :products, dependent: :destroy

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
        validate_module_parameters(process_params)

        lims_id = catalogue_params[:lims_id]
        where(lims_id: lims_id).update_all(current: false)

        accepted_catalogue_keys = %i[pipeline url lims_id]
        catalogue = create!(catalogue_params.select { |k, _v| accepted_catalogue_keys.include?(k) }
                                            .merge(current: true))

        processes = create_processes(process_params)
        create_products(product_params, processes, catalogue.id)
      end
    end
    catalogue
  end

  def self.create_processes(process_params)
    process_params.each_with_index.map do |p, _i|
      accepted_process_keys = %i[name TAT uuid process_class]
      process = Aker::Process.create!(p.select { |k, _v| accepted_process_keys.include?(k) })
      create_process_modules(p, process.id)
      process
    end
  end

  def self.create_products(product_params, processes, catalogue_id)
    product_params.each do |pp|
      accepted_product_keys =
        %i[name description product_version availability requested_biomaterial_type uuid]
      product = Product.create!(pp.select { |k, _v| accepted_product_keys.include?(k) }
                                  .merge(catalogue_id: catalogue_id))

      pp[:process_uuids].each_with_index do |uuid, i|
        process = processes.find { |pro| pro.uuid == uuid }
        # Stage is determined by the order each process uuid appears in the array, starting at zero
        Aker::ProductProcess.create!(product_id: product.id, aker_process_id: process.id, stage: i)
      end
    end
  end

  def self.validate_params_for_module(params_for_module)
    if params_for_module[:min_value] > params_for_module[:max_value]
      raise "Error in module #{params_for_module[:name]}. #{params_for_module[:min_value]} > #{params_for_module[:max_value]}" 
    end
    true
  end

  def self.validate_module_parameters(processes_params)
    processes_params.select{|p| p[:module_parameters]}.all? do |process_params|
      process_params[:module_parameters].all?{|p| validate_params_for_module(p)}
    end
  end

  def self.get_params_for_module_name(params, module_name)
    params.select{|p| p[:name] == module_name}.first if params
  end

  def self.build_process_module_from_name(name, process_id, module_parameters)
    mod = Aker::ProcessModule.where(name: name, aker_process_id: process_id).first_or_create
    params_for_module = get_params_for_module_name(module_parameters, name)
    if params_for_module
      mod.update_attributes!(min_value: params_for_module[:min_value], max_value: params_for_module[:max_value])
    end
    mod
  end

  def self.create_process_modules(process_params, process_id)
    process_params[:process_module_pairings].each do |pm|
      # Create the process module(s), if they don't already exist
      to_module = if pm[:to_step]
        build_process_module_from_name(pm[:to_step], process_id, process_params[:module_parameters])
      end

      from_module = if pm[:from_step]
        build_process_module_from_name(pm[:from_step], process_id, process_params[:module_parameters])
      end

      to_module = if pm[:to_step]
                    Aker::ProcessModule.where(name: pm[:to_step], aker_process_id: process_id)
                                       .first_or_create
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
    raise "Process module could not be validated: #{bad_modules}" unless bad_modules.empty?
  end

  def self.validate_module_name(module_name)
    uri_module_name = module_name.tr(' ', '_').downcase
    BillingFacadeClient.validate_process_module_name(uri_module_name)
  end

  # All products must have a unique name and uuid (within the catalogue)
  def self.validate_products(product_params)
    product_uuids = product_params.map { |prod| prod[:uuid] }

    raise 'Products listed in catalogue without uuids' if product_uuids.any?(&:nil?)

    if product_uuids.uniq.size != product_uuids.size
      duplicates = product_uuids.select { |uuid| product_uuids.count(uuid) > 1 }.uniq
      raise "Duplicate product uuids specified: #{duplicates.uniq}"
    end

    product_names = product_params.map { |prod| prod[:name] }

    raise 'Products listed in catalogue without names' if product_names.any?(&:nil?)

    return unless product_names.uniq.size != product_names.size

    duplicates = product_names.select { |name| product_names.count(name) > 1 }.uniq
    raise "Duplicate product names specified: #{duplicates.uniq}"
  end

  # All processes must have unique UUIDs (within the catalogue).
  # All products must reference UUIDs of processes defined in this catalogue.
  def self.validate_processes(process_params, product_params)
    raise 'Processes missing from catalogue data' if process_params.nil?

    process_uuids = process_params.map { |pro| pro[:uuid] }
    raise 'Processes are missing uuids' if process_uuids.any?(&:nil?)

    if process_uuids.uniq.size != process_uuids.size
      duplicates = process_uuids.select { |uuid| process_uuids.count(uuid) > 1 }.uniq
      raise "Duplicate process uuids specified: #{duplicates.uniq}"
    end
    products_without_processes = []
    products_with_nonexistent_processes = []
    products_with_duplicate_processes = []
    product_params.each do |prod|
      pu = prod[:process_uuids]
      if pu.blank?
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
      raise "Products listed with process uuids not defined in the catalogue:
        #{products_with_nonexistent_processes}"
    end

    return if products_with_duplicate_processes.empty?
    raise "Products in catalogue contain repeated process uuids:
      #{products_with_duplicate_processes}"
  end
end
