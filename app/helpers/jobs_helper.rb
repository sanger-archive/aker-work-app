module JobsHelper
  def job_status_label(job)
    if job.completed?
      '<span class="label label-success">Completed</span>'.html_safe
    elsif job.cancelled?
      '<span class="label label-danger">Cancelled</span>'.html_safe
    else
      "<span class='label label-default'>#{job.status.capitalize}</span>".html_safe
    end
  end
end