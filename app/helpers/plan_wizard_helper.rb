module PlanWizardHelper
  def view_set_link(set)
    return unless set
    url = Rails.configuration.urls[:sets] + '/simple/sets/' + set.uuid
    link_to(set.name, url, target: :_blank)
  end
end
