source 'https://rubygems.org'

gem 'chef', '~> 12.3'
gem 'knife-windows'
gem 'pantry_daemon_common', github: 'wongatech/pantry_daemon_common' # migrate to gems soon

group :development do
  gem 'guard-rspec'
  gem 'guard-bundler'
end

group :test, :development do
  gem 'pry'
  gem 'simplecov', require: false
  gem 'simplecov-rcov', require: false
  gem 'rspec', '~> 3.0'
  gem 'rake'
  gem 'rubocop'
  gem 'memory_profiler'
end
