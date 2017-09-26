require 'lims_client'
require 'event_message'
require 'securerandom'

class WorkOrder < ApplicationRecord
  include AkerPermissionGem::Accessible

  belongs_to :product, optional: true

  after_initialize :create_uuid
  after_create :set_default_permission_email

  validates :owner_email, presence: true

  def create_uuid
    self.work_order_uuid ||= SecureRandom.uuid
  end

  def set_default_permission_email
    set_default_permission(owner_email)
  end

  def self.ACTIVE
    'active'
  end

  def self.BROKEN
    'broken'
  end

  def self.COMPLETED
    'completed'
  end

  def self.CANCELLED
    'cancelled'
  end

  scope :for_user, -> (owner) { where(owner_email: owner.email) }
  scope :active, -> { where(status: WorkOrder.ACTIVE) }
  # status is either set, product, proposal
  scope :pending, -> { where('status NOT IN (?)', not_pending_status_list)}
  scope :completed, -> { where(status: WorkOrder.COMPLETED) }
  scope :cancelled, -> { where(status: WorkOrder.CANCELLED) }

  def materials
    SetClient::Set.find_with_materials(set_uuid).first.materials
  end

  def has_materials?(uuids)
    return true if uuids.empty?
    return false if set_uuid.nil?
    uuids_from_work_order_set = SetClient::Set.find_with_materials(set_uuid).first.materials.map(&:id)
    uuids.all? do |uuid|
      uuids_from_work_order_set.include?(uuid)
    end
  end

  def self.not_pending_status_list
    [WorkOrder.ACTIVE, WorkOrder.BROKEN, WorkOrder.COMPLETED, WorkOrder.CANCELLED]
  end

  def active?
    status == WorkOrder.ACTIVE
  end

  def closed?
    status == WorkOrder.COMPLETED || status == WorkOrder.CANCELLED
  end

  def broken!
    update_attributes(status: WorkOrder.BROKEN)
  end

  def proposal
  	return nil unless proposal_id
    return @proposal if @proposal&.id==proposal_id
	  @proposal = StudyClient::Node.find(proposal_id).first
  end

  def original_set
    return nil unless original_set_uuid
    return @original_set if @original_set&.uuid==original_set_uuid
    @original_set = SetClient::Set.find(original_set_uuid).first
  end

  def original_set=(orig_set)
    self.original_set_uuid = orig_set&.uuid
    @original_set = orig_set
  end

  def set
    return nil unless set_uuid
    return @set if @set&.uuid==set_uuid
    @set = SetClient::Set.find(set_uuid).first
  end

  def set=(set)
    self.set_uuid = set&.uuid
    @set = set
  end

  def num_samples
    self.set && self.set.meta['size']
  end

  # Create a locked set from this work order's original set.
  def create_locked_set
    self.set = original_set.create_locked_clone("Work order #{id}")
    save!
  end

  def name
    "Work Order #{id}"
  end

  def send_to_lims
    lims_url = product.catalogue.url
    LimsClient::post(lims_url, lims_data)
  end

  def all_results(result_set)
    results = result_set.to_a
    while result_set.has_next? do
      result_set = result_set.next
      results += result_set.to_a
    end
    results
  end

  def lims_data
    material_ids = SetClient::Set.find_with_materials(set_uuid).first.materials.map{|m| m.id}
    materials = all_results(MatconClient::Material.where("_id" => {"$in" => material_ids}).result_set)

    unless materials.all? { |m| m.attributes['available'] }
      raise "Some of the specified materials are not available."
    end
    material_data = materials.map do |m|
          {
            _id: m.id,
            container: nil,
            gender: m.attributes['gender'],
            donor_id: m.attributes['donor_id'],
            phenotype: m.attributes['phenotype'],
            scientific_name: m.attributes['scientific_name']
          }
    end
    describe_containers(material_ids, material_data)

    {
      work_order: {
        product_name: product.name,
        product_version: product.product_version,
        product_uuid: product.product_uuid,
        work_order_id: id,
        comment: comment,
        proposal_id: proposal_id,
        proposal_name: proposal.name,
        cost_code: proposal.cost_code,
        desired_date: desired_date,
        materials: material_data,
      }
    }
  end

  def describe_containers(material_ids, material_data)
    containers = MatconClient::Container.where("slots.material" => { "$in" => material_ids}).result_set
    material_map = material_data.each_with_object({}) { |t,h| h[t[:_id]] = t }
    while containers do
      containers.each do |container|
        container.slots.each do |slot|
          if material_ids.include? slot.material_id
            unless material_map[slot.material_id][:container]
              container_data = { barcode: container.barcode }
              container_data[:num_of_rows] = container.num_of_rows
              container_data[:num_of_cols] = container.num_of_cols
              container_data[:address] = slot.address
              material_map[slot.material_id][:container] = container_data
            end
          end
        end
      end
      containers = (containers.has_next? ? containers.next : nil)
    end
  end

  def generate_completed_and_cancel_event
    if closed?
      message = EventMessage.new(work_order: self)
      EventService.publish(message)
    else
      raise 'You cannot generate an event from a work order that has not been completed.'
    end
  end

  def generate_submitted_event
    if active?
      message = EventMessage.new(work_order: self, status: 'submitted')
      EventService.publish(message)
    else
      raise 'You cannot generate an submitted event from a work order that is not active.'
    end
  end

end
