require 'completion_cancel_steps/create_containers_step'
require 'completion_cancel_steps/create_new_materials_step'
require 'completion_cancel_steps/update_old_materials_step'
require 'completion_cancel_steps/lock_set_step'
require 'completion_cancel_steps/update_work_order_step'
require 'completion_cancel_steps/fail_step'


class WorkOrdersController < ApplicationController

  before_action :work_order, only: [:complete, :cancel]

  skip_authorization_check only: [:complete, :cancel, :get, :set_search]
  skip_credentials only: [:complete, :cancel, :get]

  # Returns JSON containing the set service query result for about the set being
  # searched
  def set_search
    connection = Faraday.new(url: "#{Rails.application.config.set_url}")
    begin
      r = connection.get('sets?filter[name]=' + params[:set_name])
      render json: r.body
    rescue Faraday::ConnectionFailed => e
      render json: nil, status: 404
    end
  end

  # -------- API ---------
  def get
    render json: work_order.lims_data_for_get, status: 200
  rescue ActiveRecord::RecordNotFound
    render json: {errors: [{status: '404', detail: 'Record not found'}]}, status: 404
  end

private

  def work_order
    wo = WorkOrder.find(params[:id])
    @work_order ||= wo.decorate
  end

  helper_method :work_order

end
