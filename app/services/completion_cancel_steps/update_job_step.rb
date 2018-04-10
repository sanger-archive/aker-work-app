class UpdateJobStep
  def initialize(job, msg, finish_status)
    @finish_status = finish_status
    @job = job
    @msg = msg
  end

  # Step 4 - Update Job
  def up
    if @finish_status == 'complete'
      @job.complete!
    elsif @finish_status == 'cancel'
      @job.cancel!
    end

  end

  def down
    if @finish_status == 'complete'
      @job.update_attributes(completed: nil)
    elsif @finish_status == 'cancel'
      @job.update_attributes(cancelled: nil)
    end
  end
end
