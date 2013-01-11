module Sidekiq
  module Middleware
    module Client
      module Stats
        class ResqueLike
          include Sidekiq::ResqueStatus
          # Store information on the current enqueued job into redis

          def call(worker, msg, queue)
            enqueue_job(worker, msg, queue)
            yield
          end
        end
      end
    end
  end
end 