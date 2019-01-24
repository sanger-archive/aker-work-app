# frozen_string_literal: true

# A sequence of work orders created for a particular product
class WorkPlan < ApplicationRecord

  SEQUENCESCAPE_LIMS_ID = "SQSC"

  belongs_to :product, optional: true
  belongs_to :data_release_strategy, optional: true

  has_many :processes, through: :product
  has_many :work_orders, -> { order(:order_index) }, dependent: :destroy

  has_many :process_module_choices, -> { order(:aker_process_id, :position) }, dependent: :destroy

  after_initialize :create_uuid
  before_validation :sanitise_owner
  before_save :sanitise_owner
  validates :owner_email, presence: true

  def create_uuid
    self.uuid ||= SecureRandom.uuid
  end

  # Convert owner email to lower case with no surrounding whitespace
  def sanitise_owner
    if owner_email
      sanitised = owner_email.strip.downcase
      if sanitised != owner_email
        self.owner_email = sanitised
      end
    end
  end

  scope :for_user, ->(user) { WorkPlans::ForUserQuery.call(user) }
  scope :modifiable_by, ->(user) { WorkPlans::ModifiableByUserQuery.call(user) }

  def name
    "Work plan #{id}"
  end

  # The status to show in the table for work plans in progress.
  # Shows "#{process} in progress" if an order is in progress,
  #  and "#{process} complete/cancelled" if the next order is waiting to be dispatched.
  def active_status
    active_order = work_orders.find(&:active?)
    return active_order.process.name+' in progress' if active_order
    last_closed = work_orders.reverse_each.find(&:closed?)
    return "#{last_closed.process.name} #{last_closed.status}" if last_closed
    '' # shouldn't happen, but don't explode
  end

  # For plans in construction, returns the step we have reached in the wizard.
  # After the wizard has been completed, revisiting it should bring you back to the dispatch step.
  def wizard_step
    return 'set' unless original_set_uuid
    return 'project' unless project_id
    return 'product' unless product_id
    return 'data_release_strategy' unless data_release_strategy_id
    'dispatch'
  end

  def broken?
    status=='broken'
  end

  def closed?
    false # There is no longer any way for plans to become closed
  end

  def active?
    status=='active'
  end

  def cancelled?
    cancelled.present?
  end

  def in_construction?
    status=='construction'
  end

  def cancellable?
    active? || in_construction?
  end

  # cancelled - the plan has been cancelled
  # broken - one of the orders is broken
  # closed - all of the orders are complete or cancelled (in some combination)
  # active - the orders are underway
  # construction - the plan is not yet underway
  def status
    return 'cancelled' if cancelled
    if project_id
      wos = work_orders.to_a # load them all now so we don't make multiple queries
      if !wos.empty?
        return 'broken' if wos.any?(&:broken?)
        return 'active'
      end
    end
    return 'construction'
  end

  def user_permitted?(accessible, user, access)
    user_policy = WorkPlanPermissionPolicy.new(user, accessible)
    user_policy.permitted?(access)
  end

  def is_product_from_sequencescape?
    product.catalogue.lims_id == SEQUENCESCAPE_LIMS_ID
  end

  def modules_for_process_id(pro_id)
    process_module_choices.select { |mc| mc.aker_process_id==pro_id }.sort_by(&:position)
  end

end
