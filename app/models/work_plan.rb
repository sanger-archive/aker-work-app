# A sequence of work orders created for a particular product
class WorkPlan < ApplicationRecord

  SEQUENCESCAPE_LIMS_ID = "SQSC"

  belongs_to :product, optional: true
  belongs_to :data_release_strategy, optional: true

  has_many :work_orders, -> { order(:order_index) }, dependent: :destroy

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

  # Find orders owned by the given user (an object with a .email attribute)
  scope :for_user, -> (owner) { where(owner_email: owner.email) }

  # Creates one work order per process in the product.
  # The process_module_ids needs to be an array of arrays of module ids to link to the respective orders.
  # The locked set uuid is passed for the first order, in case such a locked
  # set already exists
  # The product_options_selected_values is an array of arrays that matches with process_module_ids by position. It contains
  # the selected argument for the module (if any) or nil if the module does not need a selected value
  def create_orders(process_module_ids, locked_set_uuid, product_options_selected_values)
    unless product
      raise "No product is selected"
    end
    unless product.processes.length==process_module_ids.length
      raise "Bad process options passed"
    end
    unless work_orders.empty?
      return work_orders
    end
    ActiveRecord::Base.transaction do
      product.processes.each_with_index do |pro, i|
        wo = WorkOrder.create!(process: pro, order_index: i, work_plan: self, status: WorkOrder.QUEUED,
                original_set_uuid: i==0 ? original_set_uuid : nil, set_uuid: i==0 ? locked_set_uuid : nil)
        module_ids = process_module_ids[i]
        module_ids.each_with_index do |mid, j|
          WorkOrderModuleChoice.create!(work_order_id: wo.id, aker_process_modules_id: mid, position: j, selected_value: product_options_selected_values[i][j])
        end
        BrokerHandle.publish(WorkOrderEventMessage.new(work_order: wo, status: 'queued'))
      end
    end
    work_orders.reload
  end

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
    status=='closed'
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
        return 'closed' if wos.all?(&:closed?)
        return 'active' unless wos.all?(&:queued?)
      end
    end
    return 'construction'
  end

  # Everyone has :read and :create permission.
  # Only the plan owner has :write (or any other) permission.
  def permitted?(email_or_group, access)
    access = access.to_sym
    return true if access==:read || access==:create
    if email_or_group.instance_of? String
      email_or_group==owner_email
    else
      email_or_group.include?(owner_email)
    end
  end

  def is_product_from_sequencescape?
    product.catalogue.lims_id == SEQUENCESCAPE_LIMS_ID
  end

end
