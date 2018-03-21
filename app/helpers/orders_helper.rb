module OrdersHelper
  def step_classes(step_index)
    if params[:id] == wizard_steps[step_index].to_s
      "active"
    elsif step_index < wizard_steps.find_index(params[:id].to_sym)
      "complete"
    else
      "upcoming"
    end
  end

  def step_titles
    ["Select Set", "Select Project", "Select Product", "Dispatch"]
  end

end
