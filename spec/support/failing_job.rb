class FailingJob < SidekiqWorkerWithStatus
	
  def perform(*args)
    raise StandardError, 'This job is supposed to failed.'
  end
end