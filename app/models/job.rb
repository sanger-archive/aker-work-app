class Job < ApplicationRecord
  belongs_to :work_order

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

  def status
    return 'cancelled' if cancelled
    return 'queued' if [started, cancelled, completed].all?(&:nil?)
    return 'active' if !started.nil? && [cancelled, completed].all?(&:nil?)
    return 'completed' if !completed.nil? && [started, cancelled].all?(&:nil?)
  end
end