module WorkOrdersHelper

  def work_order_status_label(work_order)
    if work_order.concluded?
      '<span class="label label-success">Concluded</span>'.html_safe
    elsif work_order.active?
      '<span class="label label-primary">Active</span>'.html_safe
    elsif work_order.broken?
      '<span class="label label-danger">Broken</span>'.html_safe
    else
      "<span class='label label-default'>#{work_order.status.capitalize}</span>".html_safe
    end
  end

end
