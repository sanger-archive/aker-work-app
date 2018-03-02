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

  def sanitise_owner
    if owner_email
      sanitised = owner_email.strip.downcase
      if sanitised != owner_email
        self.owner_email = sanitised
      end
    end
  end

  # Creates one work order per process in the product.
  def create_orders
    unless product
      raise "No product is selected"
    end
    unless work_orders.empty?
      return work_orders
    end
    product.processes.each_with_index do |pro, i|
      WorkOrder.create!(process: pro, order_index: i, work_plan: self, status: WorkOrder.QUEUED)
    end
    work_orders.reload
  end

  def name
    "Work plan #{id}"
  end

  def set_selected?
    !(work_orders.empty? || work_orders.first.set_uuid.nil?)
  end

  # Returns the step we have reached in the wizard.
  # After the wizard has been completed, revisiting it should bring you back to the dispatch step.
  # The assumption of this is that we can pick the product FIRST, because we can't make the work orders
  #  until we have the product, and we don't have anywhere to put the set until we have orders.
  def wizard_step
    return 'product' unless product
    return 'set' unless set_selected?
    return 'project' unless project
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
      return 'active' if work_orders.any?(&:active?)
    end
    'construction'
  end
end
