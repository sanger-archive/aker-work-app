# frozen_string_literal: true

# Represents a Que::Job responsible for dispatching a Work Order and adding an
# event message to the queue
class DispatchWorkOrder < Que::Job
  self.retry_interval      = Rails.configuration.dispatch_queue[:retry_interval]
  self.maximum_retry_count = Rails.configuration.dispatch_queue[:maximum_retry_count]

  # Error class for when dispatching goes unexpectedly wrong
  class DispatchError < StandardError; end

  # Error class for when the Broker is broken
  class BrokerNotWorkingError < StandardError; end

  def run(work_order_id:, forwarded_job_ids: [])
    @work_order_id = work_order_id
    @forwarded_job_ids = forwarded_job_ids

    begin
      check_broker
      dispatch
    rescue StandardError, DispatchError, BrokerNotWorkingError => exception
      email_aker_devs(exception)
      raise
    end
  end

private

  attr_reader :work_order_id, :forwarded_job_ids

  def work_order
    @work_order ||= WorkOrder.find(work_order_id)
  end

  def forwarded_jobs
    @forwarded_jobs ||= Job.find(forwarded_job_ids).map(&:decorate)
  end

  def work_order_dispatcher
    @work_order_dispatcher ||= WorkOrderDispatcher.new
  end

  def work_order_mailer
    @work_order_mailer ||= WorkOrderMailer.with(work_order: work_order)
  end

  def check_broker
    raise BrokerNotWorkingError, error_message('Broker is not working.') unless broker_working?
  end

  def broker_working?
    !BrokerHandle.events_enabled? || BrokerHandle.working?
  end

  def error_message(message)
    "Work Order #{work_order.id} could not be dispatched. #{message}"
  end

  def dispatch
    if work_order_dispatcher.dispatch(work_order)
      on_success
    else
      final_attempt? ? on_expire : on_fail
    end
  end

  def on_success
    send_dispatched_event
    finish # Que helper that marks the job as finished (but doesn't destroy it in the db)
    work_order_mailer.dispatched.deliver_now
  end

  def send_dispatched_event
    work_order.reload.generate_dispatched_event(forwarded_jobs)
  end

  def on_fail
    raise DispatchError, error_message(work_order_dispatcher.errors.full_messages.join(","))
  end

  def on_expire
    work_order.broken!
    work_order_mailer.dispatch_failed.deliver_now
    on_fail
  end

  def final_attempt?
    error_count == self.class.maximum_retry_count - 1
  end

  def email_aker_devs(exception)
    Developers::WorkOrderMailer
        .with(que_job: self, work_order: work_order, exception: exception)
        .dispatch_failed
        .deliver_now
  end
end
