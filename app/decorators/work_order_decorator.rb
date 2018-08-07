class WorkOrderDecorator < Draper::Decorator
  include LinkableToSets

  delegate_all
  decorates_association :work_plan
  decorates_association :jobs
  decorates_finders

  # Links these attributes to Sets in the Set Service
  # See LinkableToSets for more
  link_to_set :set_uuid, :original_set_uuid, :finished_set_uuid

  # Make sure we have a locked set in our set field.
  # Returns true if a set has been locked during this method.
  def finalise_set
    # If we already have an input set, and it is already locked, there is nothing to do
    return false if set&.locked

    if !set && !original_set
      # No set is linked to this order
      raise "No set selected for Work Order"
    end

    anylocked = false

    if set # We already have an input set, but it needs to be locked
      if !set.update_attributes(locked: true)
        raise "Failed to lock set #{set.name}" unless set.locked
      end
      anylocked = true
    elsif original_set.locked # Our original set is already locked, so we don't need to copy it
      self.set = original_set
    else # create a locked clone of the original set as our final input set
      self.set = original_set.create_locked_clone(name)
      anylocked = true
    end
    save!
    return anylocked
  end

  def create_editable_set
    raise "Work order already has input set" if set_uuid?
    raise "Work order has no original set" unless original_set_uuid?
    set = original_set.create_unlocked_clone(name)
    save!
    set
  end

end