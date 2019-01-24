# frozen_string_literal: true

# Determines whether a Work Order is allowed to be dispatched to a LIMS.
# Uses ActiveModel::Validations so has the familiar #errors object.
#
# Current policy is:
#   - The Work Order's Work Plan's SubProject must have a parent Cost Code
#   - The Work Order must be queued
#   - The Work Plan must be active
#   - The Process Modules must be valid (validated against UBW)
#   - All the Materials in the Work Order's Input Set must be available
#   - The Work Order must have 1 or more Jobs

# Example usage:
# dwop = DispatchableWorkOrderPolicy.new
#
# dwop.dispatchable?(work_order)
#   => false
#
# dwop.errors.full_messages
#   => ["Cost Code can not be found for this Work Plan", "Work Order must have status 'queued'",...]
class DispatchableWorkOrderPolicy
  include ActiveModel::Validations

  validates :cost_code, presence: { message: 'can not be found for this Work Plan' }
  validate :work_order_is_queued
  validate :work_plan_is_active
  validate :process_modules_are_valid
  validate :materials_are_available
  validate :work_order_has_jobs

  def dispatchable?(work_order)
    @work_order = work_order
    valid?
  end

  private

  attr_reader :work_order
  delegate :work_plan, to: :work_order

  def cost_code
    @cost_code ||= work_plan.decorate.parent_cost_code
  end

  def work_order_is_queued
    errors.add(:work_order, 'must have status \'queued\'') if work_order.status != 'queued'
  end

  def work_plan_is_active
    errors.add(:work_plan, 'must have status \'active\'') if work_plan.status != 'active'
  end

  def process_modules_are_valid
    errors.add(:process_modules, "could not be validated: #{bad_module_names}") unless bad_module_names.empty?
  end

  def bad_module_names
    @bad_module_names ||= UbwClient.missing_unit_prices(process_module_names, cost_code)
  end

  def process_module_names
    work_order.process_modules.map(&:name).to_a
  end

  def materials_are_available
    errors.add(:materials, 'are not all available') if any_materials_unavailable?
  end

  def any_materials_unavailable?
    materials.any? { |material| material.available == false }
  end

  def materials
    work_order.set_full_materials
  end

  def work_order_has_jobs
    errors.add(:work_order, 'does not have any Jobs') if work_order.jobs.empty?
  end
end
