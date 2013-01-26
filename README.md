# Sidekiq::ResqueStatus

Sidekiq-resque_status is a Sidekiq plug-in that allows to manage and check the progress of resque jobs and sidekiq workers at the same place: the resque web-ui interface. Sidekiq and Resque are two different queuing systems; Depending on the type of jobs you have to process you might want to use one or the other. These two queuing systems have their own web interface. In case you are using both queuing system in one project, you will end up having two complete different web interfaces for checking and managing the status of background jobs. This gem allows you to use only one web interface by grouping the Sidekiq workers statuses under the Resque web-ui. 

## Installation

Add this line to your application's Gemfile:

    gem 'sidekiq-resque_status'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sidekiq-resque_status

## Usage

### Personalize your worker:

To add Sidekiq worker to your resque web-ui you just need to inherit your worker class with SidekiqWorkerWithStatus

		class SleepingJob < SidekiqWorkerWithStatus
		  def perform(*args)
		    sleep args[0] || 0.1
		  end
		end 

### Set up your Sidekiq connection base on your Resque one
	
In order for sidekiq-resque_status to work properly you need to tell sidekiq to use the same connection as Resque (same namespace, same url).
You can do so by creating a config file (such as sidekiq_config.rb) and doing:

		Sidekiq.configure_server do |config|
		  config.redis = {:namespace => Resque.redis.namespace, :url => url }
		end

		Sidekiq.configure_client do |config|
		  config.redis = { :namespace => Resque.redis.namespace, :url => url }
		end	

### Configure Sidekiq server and client middleware

In the same config file you just have to add sidekiq-status and sidekiq-resque_status to Sidekiq middleware.

		Sidekiq.configure_server do |config|
		  config.server_middleware do |chain|
		    chain.add Sidekiq::Status::ServerMiddleware
		    chain.add Sidekiq::Middleware::Server::Stats::ResqueLike
		  end
		end

		Sidekiq.configure_client do |config|
		  config.client_middleware do |chain|
		    chain.add Sidekiq::Status::ClientMiddleware
		    chain.add Sidekiq::Middleware::Client::Stats::ResqueLike
		  end
		end	

... And that's it, you're all set!

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
