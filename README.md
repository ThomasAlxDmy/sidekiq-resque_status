# Sidekiq::ResqueStatus

Sidekiq-resque_status is a Sidekiq plug-in that will allow you to manage and check the progress of your resque jobs and sidekiq workers under the same place: the resque web-ui interface. Sidekiq and Resque are two different queuing system and depending on the type of jobs you have to process you might want to use one or the other. These two queuing system have their own web interface. This gem allow you, in case you are using both queuing system in one project, to group them under the resque web-ui. 

## Installation

Add this line to your application's Gemfile:

    gem 'sidekiq-resque_status'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sidekiq-resque_status

## Usage

# Personalize your worker:

To add Sidekiq worker to your resque web-ui you just need inherit your worker class with SidekiqWorkerWithStatus

		class SleepingJob < SidekiqWorkerWithStatus
		  def perform(*args)
		    sleep args[0] || 0.1
		  end
		end 

# Set up your Sidekiq connection base on your Resque one
	
In order for sidekiq-resque_status to work properly you need to tell sidekiq to use the same connection as Resque (same namespace, same url).
You can do so by creating a config file (such as sidekiq_config.rb) and doing:

		Sidekiq.configure_server do |config|
		  config.redis = {:namespace => Resque.redis.namespace, :url => url }
		end

		Sidekiq.configure_client do |config|
		  config.redis = { :namespace => Resque.redis.namespace, :url => url }
		end	

# Add the sidekiq-resque_status middleware to the Sidekiq server and client middleware

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

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request