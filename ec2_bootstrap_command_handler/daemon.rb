#!/usr/bin/env ruby
require 'rubygems'
require 'daemons'
require_relative '../common/subscriber'
require_relative '../common/config'
require_relative 'ec2_bootstrap_command_handler'

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__
config = Daemons::Config.new(File.expand_path(File.join(File.dirname(THIS_FILE),"daemon.yml")))
daemon_config = {
  :backtrace => config['daemon']['backtrace'],
  :dir_mode => config['daemon']['dir_mode'].to_sym,
  :dir => "#{File.expand_path(config['daemon']['dir'])}",
  :monitor => config['daemon']['monitor']
}
Daemons.run_proc(config['daemon']['app_name'], daemon_config) {
  begin
    Daemons::Subscriber.new.subscribe(config['sqs']['queue_name'],Daemons::EC2BootstrapCommandHandler.new(config['sns']['topic_arn']))
  rescue => e
    puts "#{e}"
    retry
  end
}
