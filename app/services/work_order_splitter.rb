# Little "abstract" class for splitting Work Orders into Jobs
# Expects to be inherited by a class that implements the #splits method
# The #splits method should yield Arrays of Materials IDs

# For each split, this class will create a Job, create a Set with the Materials, and assign that
# new Set to the new Job's input_set_uuid
module WorkOrderSplitter
  class Splitter

    attr_accessor :work_order, :jobs

    def initialize
      @jobs = []
    end

    def split(work_order)
      begin
        ActiveRecord::Base.transaction do
          with_each_split(work_order.decorate) do |material_ids|
            # Create the job
            job = work_order.jobs.create!
            job = job.decorate

            # Create the Input Set
            job.create_input_set(
              name: "Job #{job.id} Input Set"
            )

            # Add the Materials to the Input Set
            job.input_set.set_materials(material_ids)

            after_create(job)

            job.save!

            jobs << job
          end

          # Done last because you can't undo it
          lock_all_sets(work_order)
        end
      rescue => e
        Rails.logger.error "WorkOrderSplitter.split failed for work order #{work_order.id}"
        Rails.logger.error ([e.message] + e.backtrace).join("\n   ")
        rollback
        return false
      end
      work_order.reload
      return true
    end

  protected

    # Expects template method to yield a list of material ids
    def with_each_split(work_order)
      raise NotImplementedError
    end

    # Doesn't have to be overidden, but helpful right now
    def after_create(job)
    end

  private

    def lock_all_sets
      with_input_sets do |set| 
        set.update_attributes(owner_id: Rails.configuration.aker_email, locked: true) 
      end
    end

    def rollback
      with_input_sets { |set| set.destroy }
    end

    def with_input_sets
      jobs.each { |job| yield job.input_set }
    end
  end
end
