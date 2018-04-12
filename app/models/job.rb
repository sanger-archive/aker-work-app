#
# This class represents a unit of job performed inside a work order for a set of biomaterial
# inside a container. Any instance could take one of the following status depending on the situation:
#
# - queued    : The job is created, but not sent to a LIMS to start its work
# - active    : The job has started
# - completed : The job was completed. This status is set by the LIMS after finishing with it
# - cancelled : The job was cancelled before completing. Same as completed, it is set by the LIMS
# - broken    : The job is broken and cannot be modified anymore
#
# The state machine could be represented as following:
#
#                 (1)                     Methods to change status:
#   QUEUED ---------------- BROKEN        (1) broken!
#     |                  (1) |||          (2) start!
# (2) |      COMPLETED ------ ||          (3) complete!
#     | (3)/             (1)  ||          (4) cancel!
#   ACTIVE ------------------- |
#       (4)\             (1)   |
#            CANCELLED --------
#
class Job < ApplicationRecord
  belongs_to :work_order

  validates :work_order, presence: true

  validate :status_ready_for_update

  scope :is_not_broken, -> { where(broken: nil) }
  scope :is_queued, -> { where(started: nil, completed: nil, cancelled: nil, broken: nil) }
  scope :is_active, -> { is_not_broken.where.not(started: nil).where(completed: nil, cancelled: nil) }
  scope :is_concluded, -> { is_not_broken.where.not(started: nil).where('(completed IS NOT NULL) OR (cancelled IS NOT NULL)') }

  # Before modifying the state for an object, it checks that the preconditions for each step have been met
  def status_ready_for_update
    # No broken job can be modified
    if broken_was
      errors.add(:base, 'cannot update, job is broken')
    end
    # A job is either completed or cancelled
    if (started && cancelled && completed)
      errors.add(:base, 'cannot be started, cancelled and completed at same time')
    end
    # A job cannot be cancelled or completed before being started
    if (cancelled || completed) && (!started)
      errors.add(:base, 'cannot be finished without starting')
    end
    # Once a job is in a status, it cannot be set again into the same status
    if id
      previous_object = Job.find(id)
      columns_to_check = [:started, :cancelled, :completed].select{|s| !previous_object.send(s).nil?}
      if ((columns_to_check & changed_attributes.keys).length > 0)
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

  def broken?
    status == 'broken'
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
    update_attributes!(broken: Time.now)
    # update the work order to be broken too, jobs can still be concluded but work plan cannot progress
    work_order.broken!
  end

  def status
    return 'broken' if broken
    return 'cancelled' if cancelled
    return 'completed' if completed
    return 'active' if started
    return 'queued'
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

  # This method returns a ActiveRecord:Relation of the jobs for a pipeline
  # It throws an exception if there is more than one catalogue, or the catalogue does not exist
  def self.get_jobs_for_pipeline(pipeline)
    catalogues = Catalogue.where('lower(pipeline) = lower(?)', pipeline).where(current: true)

    if catalogues.length!=1
      raise JSONAPI::Exceptions::RecordNotFound, "pipeline: #{pipeline}"
    end
    jobs_ids = catalogues[0].get_all_jobs
    Job.where(id: jobs_ids.map(&:id))
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
