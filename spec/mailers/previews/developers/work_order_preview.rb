# Preview all emails at http://localhost:3000/rails/mailers/developers/work_order
class Developers::WorkOrderPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/developers/work_order/dispatch_failed
  def dispatch_failed
    Developers::WorkOrderMailer.dispatch_failed
  end

end
