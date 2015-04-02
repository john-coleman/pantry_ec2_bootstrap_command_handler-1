source 'https://rubygems.org'

gem 'chef', '~> 12.2'
gem 'knife-windows'
gem 'pantry_daemon_common', git: 'git@github.com:wongatech/pantry_daemon_common.git' # migrate to gems soon

group :development do
  gem 'guard-rspec'
  gem 'guard-bundler'
end

group :test, :development do
  gem 'simplecov', require: false
  gem 'simplecov-rcov', require: false
  gem 'rspec', '~> 3.0'
  gem 'rake'
  gem 'rubocop'
end
