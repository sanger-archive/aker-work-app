# frozen_string_literal: true

# This class represents a unit of job performed inside a work order for a set of biomaterial
# inside a container. Any instance could take one of the following status depending on the
# situation:
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
  has_one :process, through: :work_order
  has_one :work_plan, through: :work_order

  has_many :work_order_module_choices, through: :work_order

  validates :work_order, presence: true

  validate :status_ready_for_update

  # Orders Jobs by the Work Plan's priority
  scope :prioritised, -> (order = 'asc') { joins(work_order: :work_plan).order("work_plans.priority #{order}") }
  scope :completed, -> { where.not(completed: nil) }
  scope :cancelled, -> { where.not(cancelled: nil) }

  # Before modifying the state for an object, it checks that the pre-conditions for each step have
  # been met
  def status_ready_for_update
    # No broken job can be modified
    broken_was && errors.add(:base, 'cannot update, job is broken')

    # A job is either completed or cancelled
    if started && cancelled && completed
      errors.add(:base, 'cannot be started, cancelled and completed at same time')
    end

    # A job cannot be cancelled or completed before being started
    if (cancelled || completed) && !started
      errors.add(:base, 'cannot be finished without starting')
    end

    # Once a job is in a status, it cannot be set again into the same status
    return unless id

    previous_object = Job.find(id)
    columns_to_check = %i[started cancelled completed].reject { |s| previous_object.send(s).nil? }

    return unless (columns_to_check & changed_attributes.keys).length.positive?

    errors.add(:base, 'cannot use the same operation twice to change the status')
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

  def start!
    update!(started: Time.zone.now)
  end

  def cancel!
    update!(cancelled: Time.zone.now)
  end

  def complete!
    update!(completed: Time.zone.now)
  end

  def broken!
    update!(broken: Time.zone.now)
    # update the work order to be broken too, jobs can still be concluded but work plan cannot
    # progress
    work_order.broken!
  end

  def status
    return 'broken' if broken
    return 'cancelled' if cancelled
    return 'completed' if completed
    return 'active' if started
    'queued'
  end

  def materials?(uuids)
    return true if uuids.empty?
    uuids_from_job = materials.map(&:id)
    return false if uuids_from_job.empty?
    uuids.all? do |uuid|
      uuids_from_job.include?(uuid)
    end
  end
end
