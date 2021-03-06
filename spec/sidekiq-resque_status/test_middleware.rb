require 'spec_helper'
require 'minitest/unit'
require 'minitest/pride'
require 'minitest/autorun'

require 'sidekiq'
require 'sidekiq/fetch'
require 'sidekiq/redis_connection'
require 'sidekiq/processor' 


REDIS = Sidekiq::RedisConnection.create(:url => "redis://localhost/15", :namespace => 'test')

class TestMiddleware < MiniTest::Unit::TestCase
  describe 'middleware chain' do
    before do
      $errors = []
      Sidekiq.redis = REDIS
      Sidekiq.redis { |conn| conn.flushall }
      sleep 0.1
    end

    let!(:redis) { Sidekiq.redis { |conn| conn } }
    let!(:job_id) { '987654321' }

    def process_job(msg)
     boss = MiniTest::Mock.new
     processor = Sidekiq::Processor.new(boss)
     actor = MiniTest::Mock.new
     actor.expect(:processor_done, nil, [processor])
     boss.expect(:async, actor, [])
     processor.process(Sidekiq::BasicFetch::UnitOfWork.new('queue:default', msg))
    end

    Sidekiq.server_middleware do |chain|
      # should only add once, second should be ignored
      chain.add Sidekiq::Status::ServerMiddleware
      chain.add Sidekiq::Middleware::Server::Stats::ResqueLike 
    end

    describe "Processing a valid job" do
      it "should add completed status information using jid" do
        msg = '{ "class": "' + SleepingJob.name + '", "args": [null], "jid": "' + job_id + '" }'
        process_job(msg)

        status = redis.get("status:#{job_id}")
        status.should_not be_nil
        status = MultiJson.load(status)

        status['status'].should == 'completed' 
        status['class'].should == SleepingJob.name
        status['queue'].should == 'default'
        status['jid'].should == job_id 
      end
    end

    describe "Processing a failing job" do
      let!(:msg) { '{ "class": "' + FailingJob.name + '", "args": [0], "jid": "' + job_id + '" }'} 

      it "should update job status to failed status" do
        process_job(msg)

        status = redis.get("status:#{job_id}")
        status.should_not be_nil
        status = MultiJson.load(status)

        status['status'].should == 'failed' 
        status['class'].should == FailingJob.name
        status['jid'].should == job_id
      end

      it "should add failed information" do
        process_job(msg)
        
        detailed_status = redis.lindex('failed', 0)
        detailed_status.should_not be_nil
        detailed_status = MultiJson.load(detailed_status)

        detailed_status['failed_at'].should == Time.now.rfc2822
        detailed_status['class'].should == FailingJob.name
        detailed_status['jid'].should == job_id
        detailed_status['args'].should == [0]
        detailed_status['exception'].should == StandardError.name
        detailed_status['error'].should == "This job is supposed to failed."
        detailed_status['backtrace'].should_not be_nil
        detailed_status['payload'].should == { 'class' => FailingJob.name, 'args' => [0] }
      end

      it "should increment the number of failed jobs" do
        nb_failed, nb_job_failed = redis.get("stat:failed").to_i, redis.get("stats:jobs:#{FailingJob.name}:failed").to_i
        process_job(msg)
        
        redis.get("stat:failed").to_i.should == nb_failed + 1
        redis.get("stats:jobs:#{FailingJob.name}:failed").to_i  == nb_job_failed + 1
      end
    end
  end
end