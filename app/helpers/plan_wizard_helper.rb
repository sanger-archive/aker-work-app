module PlanWizardHelper
  def view_set_link(set)
    return unless set
    link_to(set.name, set_url(set), target: :_blank)
  end

  def set_url(set)
    Rails.configuration.urls[:sets] + '/simple/sets/' + set.uuid
  end

  def view_set_link_with_size(set)
    view_set_link(set) + " [#{pluralize(set.meta["size"], 'sample')}]"
  end

  def unit_prices_for_work_plan(work_plan)
    return {} unless work_plan.product
    parent_cost_code = work_plan&.decorate&.parent_cost_code
    return {} unless parent_cost_code
    module_names = work_plan.product.processes.flat_map(&:process_modules).map(&:name)

    UbwClient::get_unit_prices_or_nil(module_names, parent_cost_code) || {}
  end
end
