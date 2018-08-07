# Splitter that finds all Containers for a Set, and yields the Materials in each Container
# that were also part of that Set
module WorkOrderSplitter
  class ByContainer < Splitter

    attr_reader :container

    def splits(work_order)
      work_order.set_containers.uniq.each do |container|
        @container = container
        yield container.material_ids & work_order.set_material_ids
      end
    end

    # Due to associating a Job with a single Container, we're going to
    # make this link here rather than in the WorkOrderSplitter as hopefully this can be
    # fixed in the future
    def after_create(job)
      job.container = container
      job.save!
    end

  end
end