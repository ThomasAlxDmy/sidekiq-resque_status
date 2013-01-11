module Sidekiq
  module Middleware
    module Server
      module Stats
        class ResqueLike
          include Sidekiq::ResqueStatus
          # Update the status, and add other information (such as the job description) into redis

          def call(worker, msg, queue)
            begin
              job_in_progress(worker, msg, queue)
              start_time = Time.now
              yield
              job_completed(worker, msg, queue, Time.now-start_time)
            rescue Exception => error
              job_failed(worker, msg, queue, error)
            end
          end
        end
      end
    end
  end
end
    