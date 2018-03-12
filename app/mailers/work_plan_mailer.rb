class WorkPlanMailer < ApplicationMailer
  def message_plan_updated(work_plan)
    @work_plan = work_plan
    mail(to: 'akerdev@sanger.ac.uk', subject: "Work Plan #{work_plan.id} updated")
  end
end