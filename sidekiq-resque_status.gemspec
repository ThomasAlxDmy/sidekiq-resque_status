# -*- encoding: utf-8 -*-
require File.expand_path('../lib/sidekiq-resque_status/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['Thomas Dmytryk']
  gem.email         = ['thomas@fanhattan.com', 'thomas.dmytryk@supinfo.com']
  gem.description   = %q{Sidekiq pluggin that add Sidekiq worker status to Resque web interface}
  gem.summary       = %q{sidekiq-resque_status is an extension to the Sidekiq queue system. It has been created to centralize Resque jobs statuses and Sidekiq workers statuses inside the resque-web interface.}
  gem.homepage      = ''
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'sidekiq-resque_status'
  gem.require_paths = ['lib']
  gem.version       = Sidekiq::ResqueStatus::VERSION

  gem.add_dependency 'sidekiq'
  gem.add_dependency 'sidekiq-status'
  gem.add_dependency 'resque-job-stats'
  gem.add_dependency 'multi_json', '~> 1'

  gem.add_development_dependency 'rspec'
  gem.add_development_dependency      'minitest', '~> 4'
end
