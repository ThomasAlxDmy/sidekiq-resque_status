require 'sidekiq'
require 'sidekiq-status'
require 'sidekiq-resque_status/version'
require 'sidekiq-resque_status/sidekiq_worker_with_status'

Dir["#{File.dirname(__FILE__)}/sidekiq-resque_status/middleware/**/*.rb"].each { |f| require f }
Dir["#{File.dirname(__FILE__)}/sidekiq-resque_status/sidekiq/**/*.rb"].each { |f| require f }

module Sidekiq
  module ResqueStatus

    ###
    # => This method will be called by the client middleware before enqueing a job.
    # => It stores information on the current job.
    # => These information will be display by resque web-ui each time a user is browsing:
    #   - the statuses page (provided by resque-status)
    #   - the job_stats page (provided by resque-job-stats)
    ###
    def enqueue_job(worker, msg, queue)
      now = Time.now.utc + 1

      # Resque Job Stats equivalent
      increment_stat("stats:jobs:#{worker.name}:enqueued", now)        

      # Status set to queued
      status_hash = { :time => now.to_i, :class => worker.name, :retry => false, :name => "#{worker.name}(#{msg['args']})", :status => "queued", :uuid => msg['jid'], :args => msg['args']}
      update_status("status:#{msg['jid']}", "queued", status_hash)

      # Add the job id to the _statuses key
      redis.zadd("_statuses", now.to_i, msg['jid'])
    end

    ###
    # => This method will be called by the server middleware before processing a job.
    # => It makes sure we are not loosing any information at the beggining of the process.
    # => It updates information on the current job.
    # => These information will be display by resque web-ui each time a user is browsing:
    #   - the statuses page (provided by resque-status)
    #   - the job_stats page (provided by resque-job-stats)
    ###
    def job_in_progress(worker, msg, queue)
      # When resqueue web re-enqueue a job we need to make sure worker.jid and msg[jid] are defined
      worker.jid ||= msg['jid'] ||= msg['args'].first['jid'] if msg['args'] && msg['args'].is_a?(Array)

      # Set status to working
      status_hash = set_missing_values(worker, msg, queue)
      status_hash = update_status("status:#{msg['jid']}", "working", status_hash)
    end

    ###
    # => This method will be called by the server middleware after processing a job.
    # => It adds a description of the processed jobs.
    # => It updates information on the current job.
    # => These information will be display by resque web-ui each time a user is browsing:
    #   - the statuses page (provided by resque-status)
    #   - the job_stats page (provided by resque-job-stats)
    #   - the queues page (provided by resque-web)
    ###
    def job_completed(worker, msg, queue, duration = 0)
      status_hash = complete_options(worker.to_process || 1, worker.processed || 1, duration, worker.description)
      status_hash = set_missing_values(worker, msg, queue, status_hash)

      # Status set to completed
      hash = update_status("status:#{msg['jid']}", "completed", status_hash) || {}
      time = hash["time"] || hash["run_at"]
      now = time ? Time.at(time.to_i) : Time.now.utc

      # Resque job Stats equivalent
      increment_stat("stats:jobs:#{msg['jid']}:timeseries:performed", now)
      increment_stat("stats:jobs:#{worker.class.name}:performed", now)

      # Set duration
      redis.rpush("stats:jobs:#{worker.class.name}:duration", duration) 
      redis.rpush("stats:jobs:#{msg['jid']}:duration", duration) 

      # remove job from the queue tab
      redis.lpop("queue:#{queue}")
    end

    ###
    # => This method will be called by the server middleware each time a job failed.
    # => It adds a complete description of the failure. 
    # => It updates information on the current job.
    # => It makes sure the job can be replay.
    # => These information will be display by resque web-ui each time a user is browsing:
    #   - the failed page (provided by resque-web)
    ###
    def job_failed(worker, msg, queue, error)
      hash = merge_value("status:#{msg['jid']}", {"status" => "failed", "message" => error.message})
      update_status("status:#{msg['jid']}", "failed", hash)

      # pass the jid into args hash to replay the job
      args = msg['args'].is_a?(Array) && msg['args'].first.is_a?(Hash) ? [msg['args'].first.merge({'jid' => msg['jid']})] : msg['args']

      failed_message = {
                          :failed_at => Time.now.rfc2822,
                          :payload => {"class" => worker.class.name, "args" => args},
                          :class => worker.class.name,
                          :exception => error.class.name,
                          :error => error.message,
                          :backtrace => error.backtrace, 
                          :worker => queue,
                          :queue => queue, 
                          :args => args,
                          :jid => msg['jid']
                        }
      # Push the failed information into redis
      redis.rpush('failed', MultiJson.dump(failed_message))

      # Increment failed statistics for job Stats 
      increment_stat("stats:jobs:#{worker.class.name}:failed", Time.now)  
      increment_expire_key("stat:failed")
    end

    private

    ###
    # => Return the redis connection
    ###
    def redis
      @redis ||= Sidekiq.redis {|conn| conn}
    end

    ###
    # => Return hash containing some statistics about the processed job
    ###
    def complete_options(total_to_process, total_processed, duration = 0, message = nil)
      average = (duration/total_processed rescue 0).round(1)
      time = duration.round(1)

      message ||= "processed #{total_processed} in A: #{average} T: #{time}"
      {"status" => "completed", :total => total_to_process, :num => total_processed, :message => message}
    end

    ###
    # => Increment a given key and set an expiration date
    ###
    def increment_expire_key(key, duration = nil)
      redis.expire(key, duration) if duration
      redis.incr(key)
    end

    ###
    # => Build Hourly, Daily and Global statistics that will be used by resque-job-stats
    ###
    def increment_stat(key, now)
      # Increment global stats
      increment_expire_key(key)

      # Increment hourly stats
      increment_expire_key(key + ":#{now.hour}:#{now.min}:#{now.sec}", 3660)

      # Increment daily stats
      increment_expire_key(key + ":#{now.hour}:#{now.min}", 900000)
    end

    ###
    # => Update the status of a job and add more information to it if requested
    ###
    def update_status(key, status, hash = nil)
      status_hash = merge_value(key, {"status" => status}) || {}
      status_hash.merge!(hash) if hash

      redis.set(key, MultiJson.dump(status_hash)) 
      redis.expire(key, 260000)
      status_hash
    end

    ###
    # => Get the value of a key and merge it 
    ###
    def merge_value(key,hash)
      value = redis.get(key)
      MultiJson.load(value).merge(hash) if value
    end

    ###
    # => Ensure we always get track of the important informations concerning the worker
    ###
    def set_missing_values(worker, msg, queue, status_hash = {})
      status_hash['jid'] = msg['jid'] if status_hash['jid'].nil?
      status_hash['queue'] = queue if status_hash['queue'].nil?
      status_hash['class'] = worker.class.name if status_hash['class'].nil?
      status_hash
    end
  end
end
