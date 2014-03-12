source 'https://rubygems.org'

gem "chef", "~> 11.10"
gem "knife-windows", "~> 0.5.12"
gem 'pantry_daemon_common', git: 'git@github.com:wongatech/pantry_daemon_common.git', tag: 'v0.2.3'

group :development do
  gem 'guard-rspec'
  gem 'guard-bundler'
end

group :test, :development do
  gem 'em-winrm', git: 'https://github.com/pmorton/em-winrm.git', branch: 'new-eventmachine'
  gem 'simplecov', require: false
  gem 'simplecov-rcov', require: false
  gem 'rspec-fire'
  gem 'rspec'
  gem 'pry-debugger'
  gem 'rake'
end
