class WorkOrderSerializer

  attr_reader :job_serializer_class, :job_serializer

  def initialize(options = {})
    @job_serializer_class = options.fetch(:job_serializer_class, JobSerializer)
    @job_serializer       = job_serializer_class.new
  end

  def serialize(work_order)
    {
      data: work_order.jobs.map { |job| job_serializer.serialize(job) }
    }
  end
end