require 'spec_helper'
require 'sidekiq/testing/inline'

describe Sidekiq::ResqueStatus do

  let!(:redis) { Sidekiq.redis { |conn| conn } }

  # Clean Redis before each test
  # Seems like flushall has no effect on recently published messages,
  # so we should wait till they expire
  before { redis.flushall; sleep 0.1 }

  describe "Enqueuing a job" do
    it "should increment the number of enqueued jobs" do
      nb_enqueued = redis.get("stats:jobs:#{SleepingJob.name}:enqueued").to_i
      SleepingJob.perform_async(1)

      redis.get("stats:jobs:#{SleepingJob.name}:enqueued").to_i.should == nb_enqueued + 1
    end
  end
end