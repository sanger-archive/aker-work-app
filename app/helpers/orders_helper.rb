module OrdersHelper
  def step_classes(step)
    steps = { "set" => 1, "proposal" => 2, "product" => 3, "cost" => 4, "summary" => 5 }
    if params[:id] == "set" && step == 1
      "active"
    elsif params[:id] == "proposal" && step == 2
      "active"
    elsif params[:id] == "product" && step == 3
      "active"
    elsif params[:id] == "cost" && step == 4
      "active"
    elsif params[:id] == "summary" && step == 5
      "active"
    elsif step < steps[params[:id]]
      "complete"
    else
      "upcoming"
    end
  end

end
