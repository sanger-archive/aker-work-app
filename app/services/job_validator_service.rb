require 'set'

class JobValidatorService
  attr_reader :job, :msg, :errors

  def initialize(job, msg)
    @job = job
    @msg = msg
    @errors = {}
  end

  def validate?
    [
      :correct_status?,                    # - Job status
      # :json_schema_valid?,                 # - JSON Schema
      :job_exists?,                        # - Validate job exists
      :job_has_updated_materials?,         # - Validate materials are in the original job
      :updated_materials_unique?,          # should not have two updates for the same material
      :containers_unique?,                 # - should not specify a barcode twice
      :material_locations_unique?,         # - should not specify the same exact location twice
      :material_locations_match_containers?, # - container barcodes correspond to material locations
      :containers_have_no_changes?          #  Containers that exist already should be as described
    ].all? {|m| send(m) }
  end

private

  def correct_status?
    return true if @job.status == 'active'
    error_return(422, "The job status should be active. Currently it is #{@job.status}")
  end

  # TODO
  # def json_schema_valid?
  #   list = JSON::Validator.fully_validate(schema_content, @msg)
  #   return true if list.length == 0
  #   error_return(422, "The job does not comply with the schema at #{schema_url} because: #{list.join(',')}")
  # end

  def job_exists?
    job = Job.find_by(id: @msg[:job][:job_id])
    if @job.nil?
      return error_return(404, "Job #{@msg[:job][:job_id]} does not exist")
    end
    return true if job == @job
    error_return(422, "Wrong job specified")
  end

  def job_has_updated_materials?
    return true if @job.has_materials?(@msg[:job][:updated_materials].pluck(:_id))
    error_return(422, "The updated materials don't belong to this job")
  end

  def updated_materials_unique?
    return true unless any_repeated_materials(@msg[:job][:updated_materials])
    error_return(422, 'Updated materials should not contain repeated materials')
  end

  def any_repeated_materials(materials)
    material_ids = materials.map { |m| m[:_id] }
    return material_ids.uniq.length != material_ids.length
  end

  def containers_unique?
    barcodes = @msg[:job][:containers].map { |c| c[:barcode] }
    return true if barcodes.uniq.length == barcodes.length
    error_return(422, 'Container barcodes must be unique')
  end

  def material_locations_unique?
    return true unless any_material_location_repeated?(@msg[:job][:new_materials])
    error_return(422, 'The materials cannot share locations.')
  end

  def material_locations_match_containers?
    location_barcodes = @msg[:job][:new_materials].
      map { |mat| mat[:container] }.
      select { |loc| loc }.
      map { |loc| loc[:barcode] }.
      uniq
    container_barcodes = @msg[:job][:containers].map { |c| c[:barcode] }
    unless location_barcodes.all? { |bc| container_barcodes.include?(bc) }
      return error_return(422, 'Barcodes used as material locations should be specified as containers')
    end
    unless container_barcodes.all? { |bc| location_barcodes.include?(bc) }
      return error_return(422, 'Containers specified should be used as locations for materials')
    end
    return true
  end

  def any_material_location_repeated?(new_materials)
    barcodes_without_address = new_materials.
      map { |m| m[:container] }.
      select { |loc| loc && loc[:address].nil? }.
      map { |loc| loc[:barcode] }
    return true if barcodes_without_address.uniq.length != barcodes_without_address.length
    barcodes_with_address = new_materials.
      map { |m| m[:container] }.
      select { |loc| loc && loc[:address] }.
      map { |loc| [loc[:barcode], loc[:address]] }
    return true if barcodes_with_address.uniq.length != barcodes_with_address.length
    return true if barcodes_with_address.any? { |ba| barcodes_without_address.include?(ba[0]) }

    false
  end

  def containers_have_no_changes?
    return true unless containers_have_changed?(@msg[:job][:containers])
    error_return(422, "Some of the containers provided have a different content in the container service")
  end

  def containers_have_changed?(containers_msg)
    containers_msg.any? do |container_msg|
      container = MatconClient::Container.where(barcode: container_msg[:barcode]).first
      container.present? && container_msg.keys.any? do |field|
        field!=:barcode && container_msg[field]!=container.send(field)
      end
    end
  end

  def schema_url
    ActionController::Base.helpers.asset_url(Rails.configuration.job_completion_json)
  end

  def schema_content
    return self.class.schema_content
  end

  def self.schema_content
    env = Sprockets::Railtie.build_environment(Rails.application)
    env.find_asset(Rails.configuration.job_completion_json).to_s
  end

  def error_return(status, msg)
    @errors[:status] = status
    @errors[:msg] = msg
    false
  end

end
