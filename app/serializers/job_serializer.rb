class JobSerializer

  def serialize(job)
    job = job.decorate

    # Make the assumption a Job only has one Container...
    container = job.input_set_containers.first

    {
      type: 'jobs',
      id: job.id,
      attributes: {
        job_id: job.id,
        job_uuid: job.uuid,
        work_order_id: job.work_order.id,
        aker_job_url: job_url(job),

        process_name: job.work_order.process.name,
        process_uuid: job.work_order.process.uuid,
        modules: job.work_order.process_modules.pluck(:name),
        comment: job.work_order.work_plan.comment,
        priority: job.work_order.work_plan.priority,

        project_uuid: job.work_order.work_plan.project.node_uuid,
        project_name: job.work_order.work_plan.project.name,
        data_release_uuid: job.work_order.work_plan.data_release_strategy_id,
        cost_code: job.work_order.work_plan.project.cost_code,

        # We're making a very BOLD (and very wrong very shortly) assumption that there will only
        # be one container...
        materials: build_materials(job.input_set_full_materials, container),

        container: {
          container_id: container.id,
          barcode: container.barcode,
          num_of_rows: container.num_of_rows,
          num_of_cols: container.num_of_cols
        }
      }
    }
  end

  private

  def job_url(job)
    Rails.application.config.urls[:work] + '/api/v1/jobs/' + job.id.to_s
  end

  def address_for_material(container, material)
    container.slots.find { |slot| slot.material_id == material.id }.address
  end

  def build_materials(materials, container)
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
  end
end