#!/usr/bin/env ruby
require 'rubygems'
require 'wonga/daemon'
require_relative 'ec2_bootstrap_command_handler/ec2_bootstrap_command_handler'

config_name = File.join(File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__), 'config', 'daemon.yml')
Wonga::Daemon.load_config(File.expand_path(config_name))
Wonga::Daemon.run(Wonga::Daemon::EC2BootstrapCommandHandler.new(Wonga::Daemon.publisher,
                                                                Wonga::Daemon.error_publisher,
                                                                Wonga::Daemon.config['chef'],
                                                                Wonga::Daemon.aws_resource,
                                                                Wonga::Daemon.logger))
