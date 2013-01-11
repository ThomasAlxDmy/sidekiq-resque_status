module Sidekiq

  # Monkey patch to overide the run_at attribute (Time instead of unix timestamp)
  # and remove the failed key incrementation
  class Processor
    private
    def stats(worker, msg, queue)
      redis do |conn|
        conn.multi do
          conn.sadd('workers', self)
          conn.setex("worker:#{self}:started", EXPIRY, Time.now.to_s)
          hash = {:queue => queue, :payload => msg, :run_at => Time.now }
          conn.setex("worker:#{self}", EXPIRY, Sidekiq.dump_json(hash))
        end
      end

      dying = false
      begin
        yield
      rescue Exception
        dying = true
        raise
      ensure
        redis do |conn|
          conn.multi do
            conn.srem("workers", self)
            conn.del("worker:#{self}")
            conn.del("worker:#{self}:started")
            conn.incrby("stat:processed", 1)
          end
        end
      end
    end
  end
end