class SleepingJob < SidekiqWorkerWithStatus

  def perform(*args)
    sleep args[0] || 0.1
  end
end