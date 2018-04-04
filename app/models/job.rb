class Job < ApplicationRecord
  belongs_to :work_order

  validates :work_order, presence: true

  validate :status_ready_for_update

  def status_ready_for_update
    if (started && cancelled && completed)
      errors.add(:base, 'cannot be started, cancelled and completed at same time')
    end
    if (cancelled || completed) && (!started)
      errors.add(:base, 'cannot be finish without starting')
    end
    if id
      previous_object = Job.find(id)
      if [:started, :cancelled, :completed].any?{|s| (!previous_object.send(s).nil? && !send(s).nil? && (previous_object.send(s) != send(s)))}
        errors.add(:base, 'cannot use the same operation twice to change the status')
      end
    end
  end

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

  def send_to_lims
    lims_url = work_order.work_plan.product.catalogue.url
    LimsClient::post(lims_url, lims_data)
  end

  def start!
    update_attributes!(started: Time.now)
  end

  def cancel!
    update_attributes!(cancelled: Time.now)
  end

  def complete!
    update_attributes!(completed: Time.now)
  end

  def broken!
    # TODO: figure out what to do when broken
  end

  def status
    return 'cancelled' if cancelled
    return 'queued' if [started, cancelled, completed].all?(&:nil?)
    return 'active' if !started.nil? && [cancelled, completed].all?(&:nil?)
    return 'completed' if !completed.nil? && !started.nil? && cancelled.nil?
  end

  def container
    @container ||= MatconClient::Container.find(container_uuid)
  end

  def original_set_material_ids
    @original_set_material_ids ||= work_order.materials.map(&:id)
  end

  def material_ids
    @material_ids ||= container.slots.map(&:material_id).compact & original_set_material_ids
  end

  def materials
    @materials ||= MatconClient::Material.where("_id" => {"$in" => material_ids })
  end

  def address_for_material(container, material)
    container.slots.select{|slot| slot.material_id == material.id}.first.address
  end

  def has_materials?(uuids)
    return true if uuids.empty?
    uuids_from_job = materials.map(&:id)
    return false if uuids_from_job.empty?
    uuids.all? do |uuid|
      uuids_from_job.include?(uuid)
    end
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


    {
      job: {
        job_id: id,
        work_order_id: work_order.id,

        process_name: work_order.process.name,
        process_uuid: work_order.process.uuid,
        modules: work_order.module_choices,
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
      }
    }
  end

end
