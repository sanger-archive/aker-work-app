class Job < ApplicationRecord
  belongs_to :work_order

  validates :work_order, presence: true

  def queued?
    status == 'queued'
  end

  def active?
    status == 'active'
  end

  def cancelled?
    status == 'cancelled'
  end

  def completed?
    status == 'completed'
  end

  def start!
    lims_url = work_order.work_plan.product.catalogue.url
    LimsClient::post(lims_url, lims_data)

    update_attributes(started: Time.now)
  end

  def cancel!
    update_attributes(cancelled: Time.now)
  end

  def complete!
    update_attributes(completed: Time.now)
  end

  def status
    return 'cancelled' if cancelled
    return 'queued' if [started, cancelled, completed].all?(&:nil?)
    return 'active' if !started.nil? && [cancelled, completed].all?(&:nil?)
    return 'completed' if !completed.nil? && [started, cancelled].all?(&:nil?)
  end

  def container
    @container ||= MatconClient::Container.find(container_uuid)
  end

  def material_ids
    @material_ids ||= container.slots.map(&:material_id).compact
  end

  def materials
    @materials ||= MatconClient::Material.where("_id" => {"$in" => material_ids })
  end

  def address_for_material(container, material)
    container.slots.select{|slot| slot.material_id == material.id}.first.address
  end

  # This method returns a JSON description of the order that will be sent to a LIMS to order work.
  # It includes information that must be loaded from other services (study, set, etc.).
  def lims_data
    material_data = materials.map do |m|
      main_data = 
        {
          _id: m.id,
          is_tumour: m.attributes['is_tumour'],
          supplier_name: m.attributes['supplier_name'],
          taxon_id: m.attributes['taxon_id'],
          tissue_type: m.attributes['tissue_type'],
          gender: m.attributes['gender'],
          donor_id: m.attributes['donor_id'],
          phenotype: m.attributes['phenotype'],
          scientific_name: m.attributes['scientific_name'],
          available: m.attributes['available']
        }
      address =  address_for_material(container, m)
      main_data[:address] = address if address
      main_data
    end

    project = work_order.work_plan.project
    cost_code = project.cost_code
    if project.subproject?
      project = StudyClient::Node.find(project.parent_id).first
    end

    {
      job: {
        job_id: id,
        process_name: work_order.process.name,
        process_uuid: work_order.process.uuid,
        work_order_id: work_order.id,
        comment: work_order.work_plan.comment,
        project_uuid: project.node_uuid,
        project_name: project.name,
        data_release_uuid: project.data_release_uuid,
        cost_code: project.cost_code,
        materials: material_data,
        container: {
          container_id: container.id,
          barcode: container.barcode,
          num_of_rows: container.num_of_rows,
          num_of_cols: container.num_of_cols
        },
        modules: work_order.module_choices
      }
    }
  end

end