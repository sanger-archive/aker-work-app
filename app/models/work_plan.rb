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
end
