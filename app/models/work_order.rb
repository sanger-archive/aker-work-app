require 'lims_client'

class WorkOrder < ApplicationRecord
  include AkerPermissionGem::Accessible
  belongs_to :product, optional: true
  belongs_to :user

  after_create :set_default_permission_email

  def set_default_permission_email
    set_default_permission(user.email)
  end

  def self.ACTIVE
    'active'
  end

  scope :for_user, ->(user) { where(user_id: user.id) }
  scope :active, -> { where(status: WorkOrder.ACTIVE) }
  scope :pending, -> { where.not(status: WorkOrder.ACTIVE) }

  def active?
    status == WorkOrder.ACTIVE
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

  def send_to_lims
    lims_url = product.catalogue.url
    LimsClient::post(lims_url, lims_data)
  end

  def all_results(result_set)
    return result_set unless result_set.has_next?
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
    material_data = materials.map do |m|
          {
            material_id: m.id,
            container: nil,
            gender: m.attributes['gender'],
            donor_id: m.attributes['donor_id'],
            phenotype: m.attributes['phenotype'],
            common_name: m.attributes['common_name']
          }
    end
    describe_containers(material_ids, material_data)

    {
      work_order: {
        product_name: product.name,
        product_version: product.product_version,
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
    material_map = material_data.each_with_object({}) { |t,h| h[t[:material_id]] = t }
    while containers do
      containers.each do |container|
        container.slots.each do |slot|
          if material_ids.include? slot.material_id
            unless material_map[slot.material_id][:container]
              container_data = { barcode: container.barcode }
              if (container.num_of_rows > 1 || container.num_of_cols > 1)
                container_data[:address] = slot.address
              end
              material_map[slot.material_id][:container] = container_data
            end
          end
        end
      end
      containers = (containers.has_next? ? containers.next : nil)
    end
  end

end
