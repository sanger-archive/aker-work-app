module OrdersHelper
  def step_classes(step)
    steps = { "set" => 1, "proposal" => 2, "product" => 3, "cost" => 4, "summary" => 5 }
    if params[:id] == steps.key(step)
      "active"
    elsif step < steps[params[:id]]
      "complete"
    else
      "upcoming"
    end
  end

end
