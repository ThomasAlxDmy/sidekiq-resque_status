class SidekiqWorkerWithStatus
	include Sidekiq::Worker 
  include Sidekiq::ResqueStatus

  attr_accessor :processed, :to_process, :description
end 