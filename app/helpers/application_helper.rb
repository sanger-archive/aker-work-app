module ApplicationHelper
  def total_TAT(work_order)
    # Calculate sum of work order processes TAT
    work_order.product.processes.map{|process| process.TAT}.inject(0, :+)
  end
end
