class DispatchWorkOrder < Que::Job

  self.retry_interval      = Rails.configuration.dispatch_queue[:retry_interval]
  self.maximum_retry_count = Rails.configuration.dispatch_queue[:maximum_retry_count]

  def run(work_order_id:, forwarded_job_ids: [])
    @work_order_id = work_order_id
    @forwarded_job_ids = forwarded_job_ids

    begin
      raise BrokerNotWorkingError.new(work_order) if BrokerHandle.events_enabled? && !BrokerHandle.working?
      dispatch!
    rescue => e
      Developers::WorkOrderMailer.with(que_job: self, work_order: work_order, exception: e).dispatch_failed.deliver_now
      raise
    end
  end

  class JobError < StandardError
    attr_reader :work_order

    def initialize(work_order)
      @work_order = work_order
      super(message)
    end

    def message
      "Work Order #{work_order.id} could not be dispatched."
    end
  end

  class DispatchError < JobError
    attr_reader :dispatcher

    def initialize(work_order, dispatcher)
      @work_order, @dispatcher = work_order, dispatcher
      super(work_order)
    end

    def message
      "#{super} \n\n#{dispatcher.errors.full_messages.join('\n')}"
    end
  end

  class BrokerNotWorkingError < JobError
    def message
      "#{super} Broker is not working."
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

  def dispatch!
    if work_order_dispatcher.dispatch(work_order)
      on_success
    else
      is_final_attempt? ? on_expire : on_fail
    end
  end

  def on_success
    send_dispatched_event
    finish # QueHelper: Marks the Job as finished (but doesn't destroy it in the db)
    work_order_mailer.dispatched.deliver_now
  end

  def send_dispatched_event
    work_order.reload.generate_dispatched_event(forwarded_jobs)
  end

  def on_fail
    raise DispatchError.new(work_order, work_order_dispatcher)
  end

  def on_expire
    work_order.broken!
    work_order_mailer.dispatch_failed.deliver_now
    on_fail
  end

  def is_final_attempt?
    error_count == self.class.maximum_retry_count - 1
  end

end