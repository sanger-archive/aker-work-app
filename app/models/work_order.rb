require 'lims_client'
require 'event_message'
require 'securerandom'

# A work order, either in the progress of being defined (pending),
# or fully defined and waiting to be concluded (active),
# or one where all the jobs have either been completed or cancelled (concluded).
class WorkOrder < ApplicationRecord
  include AkerPermissionGem::Accessible

  belongs_to :work_plan
  belongs_to :process, class_name: "Aker::Process", optional: false
  has_many :work_order_module_choices, dependent: :destroy
  has_many :process_modules, class_name: "Aker::ProcessModule", through: :work_order_module_choices
  has_many :jobs, dependent: :destroy

  after_initialize :create_uuid

  delegate :owner_email, to: :work_plan

  attr_accessor :rollback_materials

  def create_uuid
    self.work_order_uuid ||= SecureRandom.uuid
  end

  # The work order is in the 'active' state when not all jobs have been
  # compelted or cancelled
  def self.ACTIVE
    'active'
  end

  # The work order is in the 'broken' state when processing some operation
  # on it failed, and the correct state could not be recovered.
  # A broken work order can only be fixed by manual intervention.
  def self.BROKEN
    'broken'
  end

  # The work order is in the 'concluded' state when the jobs have all been completed or cancelled
  def self.CONCLUDED
    'concluded'
  end

  # The work order is in the 'queued' state when no jobs have been created
  def self.QUEUED
    'queued'
  end

  def total_tat
    process&.TAT
  end

  scope :active, -> { where(status: WorkOrder.ACTIVE) }
  scope :pending, -> { where('status NOT IN (?)', not_pending_status_list)}
  scope :concluded, -> { where(status: WorkOrder.CONCLUDED) }

  def self.not_pending_status_list
    [WorkOrder.ACTIVE, WorkOrder.BROKEN, WorkOrder.CONCLUDED]
  end

  def pending?
    # Returns true if the work order wizard has not yet been completed
    WorkOrder.not_pending_status_list.exclude?(status)
  end

  def active?
    status == WorkOrder.ACTIVE
  end

  def closed?
    status == WorkOrder.CONCLUDED
  end

  def queued?
    status == WorkOrder.QUEUED
  end

  def broken!
    update_attributes(status: WorkOrder.BROKEN)
  end

  def broken?
    status == WorkOrder.BROKEN
  end

  def concluded?
    status == WorkOrder.CONCLUDED
  end

  def dispatched?
    active? || concluded?
  end

# checks work_plan is not cancelled, work order is queued, and the first order in the work plan not to be closed
  def can_be_dispatched?
    (!work_plan.cancelled? && queued? && work_plan.work_orders.find {|o| !o.closed? }==self)
  end

  def name
    "Work Order #{id}"
  end

  def lims_data_for_get
    data = {work_order: {jobs: jobs.map(&:lims_data) }}
    unless data[:work_order].nil?
      data[:work_order][:status] = status
    end
    data
  end

  def selected_path
    path = []
    module_choices = WorkOrderModuleChoice.where(work_order_id: id)
    module_choices.each do |c|
      mod = Aker::ProcessModule.find(c.aker_process_modules_id)
      path.push({name: mod.name, id: mod.id, selected_value: c.selected_value})
    end
    path
  end

  def estimated_completion_date
    return nil unless dispatch_date && process
    dispatch_date + process.TAT
  end

  def generate_concluded_event
    begin
      if closed?
        message = WorkOrderEventMessage.new(work_order: self, status: 'concluded')
        BrokerHandle.publish(message)
        BillingFacadeClient.send_event(self, status)
      else
        Rails.logger.error('Concluded event cannot be generated from a work order where all the jobs are not either cancelled or completed.')
      end
    rescue => e
      Rails.logger.error e
      Rails.logger.error e.backtrace
    end
  end

  def generate_dispatched_event
    begin
      if active?
        message = WorkOrderEventMessage.new(work_order: self, status: 'dispatched')
        BrokerHandle.publish(message)
        BillingFacadeClient.send_event(self, 'dispatched')
      else
        Rails.logger.error("dispatched event cannot be generated from a work order that is not active.")
      end
    rescue => e
      Rails.logger.error e
      Rails.logger.error e.backtrace
    end
  end

  # The next order in the work plan (or nil if there is none)
  def next_order
    WorkOrder.where(work_plan_id: work_plan_id, order_index: order_index+1).first
  end
end
