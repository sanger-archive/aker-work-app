module PlanWizardHelper
  def view_set_link(set)
    return unless set
    url = Rails.application.config.set_shaper_url+'/simple/sets/'+set.uuid
    link_to(set.name, url, target: :_blank)
  end
end
