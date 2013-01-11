require 'sidekiq-resque_status'
Dir["#{File.dirname(__FILE__)}/support/*.rb"].each { |f| require f }

# Add Sidekiq-status and sidekiq-resque_status to the server and client middleware
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