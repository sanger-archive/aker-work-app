class ProductsController < ApplicationController
  skip_authorization_check only: [:get_product_description]

  def show_product_inside_work_order
    @work_order = WorkOrder.find(params[:id])
    authorize! :read, @work_order

    @product = Product.find(params[:product_id])
    cost_code = @work_order.proposal.cost_code
    price = BillingFacadeClient.get_unit_price(cost_code, @product.name)

    render json: @product.as_json.merge(unit_price: price, cost_code: cost_code).to_json
  end

  # Returns JSON containing the set service query result for about the set being
  # searched
  def get_product_description
    product_id = params["product_id"]
    # Currently assuming there is only one process to one product
    process = Product.find(product_id).processes[0]
    process_module_pairings = Aker::ProcessModulePairings.where(aker_process_id: process.id)

    available_links = build_available_links(process_module_pairings)
    default_path = build_default_path(process_module_pairings)

    render json: { "data": { "available_links": available_links, "default_path": default_path } }
  end

  def build_available_links(pairings)
    available_links = Hash.new{|h,k| h[k] = [] }

    pairings.each do |pmp|
      from_step = pmp.from_step_id ? Aker::ProcessModule.find(pmp.from_step_id) : nil
      to_step = pmp.to_step_id ? Aker::ProcessModule.find(pmp.to_step_id) : nil

      if from_step.nil? && pmp.default_path == true
        next_default_id = to_step.id
      end

      if from_step.nil?
        available_links['start'] << to_step.name
      elsif to_step.nil?
        available_links[from_step.name] << 'end'
      else
        available_links[from_step.name] << to_step.name
      end
    end
    available_links
  end

  def build_default_path(pairings)
    default_path_ids = []

    start = pairings.where(from_step_id: nil, default_path: true)
    # assuming there is only one starting link
    default_path_ids << start[0].to_step_id

    default_path_list = pairings.where(default_path: true)
    # default_path_list.length-1 as we dont want to include the final nil to_step
    until default_path_ids.length == default_path_list.length-1
      next_module = Aker::ProcessModulePairings.where(from_step_id: default_path_ids.last, default_path: true)
      default_path_ids << next_module[0].to_step_id unless next_module[0].to_step_id == nil
    end

    default_path_ids.map{ |id| Aker::ProcessModule.find(id).name }
  end

end
