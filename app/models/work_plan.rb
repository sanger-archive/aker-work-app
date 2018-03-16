# A sequence of work orders created for a particular product
class WorkPlan < ApplicationRecord
  belongs_to :product, optional: true
  has_many :work_orders, -> { order(:order_index) }, dependent: :destroy
  after_initialize :create_uuid
  before_validation :sanitise_owner
  before_save :sanitise_owner
  validates :owner_email, presence: true

  def create_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def project
    return nil unless project_id
    return @project if @project&.id==project_id
    @project = StudyClient::Node.find(project_id).first
  end

  # This is the set chosen by the user that will be the "original set" for the first
  #  work order (when that is created)
  def original_set
    return nil unless original_set_uuid
    return @original_set if @original_set&.uuid==original_set_uuid
    begin
      @original_set = SetClient::Set.find(original_set_uuid).first
    rescue JsonApiClient::Errors::NotFound => e
      return nil
    end
  end

  def num_original_samples
    original_set && original_set.meta['size']
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
  def create_orders(process_module_ids, locked_set_uuid)
    unless product
      raise "No product is selected"
    end
    unless product.processes.length==process_module_ids.length
      raise "Bad process options passed"
    end
    unless work_orders.empty?
      return work_orders
    end
    product.processes.each_with_index do |pro, i|
      wo = WorkOrder.create!(process: pro, order_index: i, work_plan: self, status: WorkOrder.QUEUED,
              original_set_uuid: i==0 ? original_set_uuid : nil, set_uuid: i==0 ? locked_set_uuid : nil)
      module_ids = process_module_ids[i]
      module_ids.each_with_index do |mid, j|
        WorkOrderModuleChoice.create!(work_order_id: wo.id, aker_process_modules_id: mid, position: j)
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
    return 'project' unless project
    return 'product' unless product
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

  def in_construction?
    status=='construction'
  end

  # broken - one of the orders is broken
  # closed - all of the orders are complete or cancelled (in some combination)
  # active - the orders are underway
  # construction - the plan is not yet underway
  def status
    if project && !work_orders.empty?
      return 'broken' if work_orders.any?(&:broken?)
      return 'closed' if work_orders.all?(&:closed?)
      return 'active' if (work_orders.any?(&:active?) || work_orders.any?(&:closed?) && work_orders.any?(&:queued?))
    end
    'construction'
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
end
