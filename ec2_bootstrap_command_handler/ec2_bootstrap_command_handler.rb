require 'common/aws_resource'
require 'common/publisher'
require 'chef/knife'
require 'chef/knife/bootstrap'
require 'chef/knife/bootstrap_windows_winrm'

Chef::Knife::Bootstrap.load_deps
Chef::Knife::BootstrapWindowsWinrm.load_deps

require 'chef/application/knife'
Chef::Knife::Bootstrap.options = Chef::Application::Knife.options.merge(Chef::Knife::Bootstrap.options)
Chef::Knife::BootstrapWindowsWinrm.options = Chef::Application::Knife.options.merge(Chef::Knife::BootstrapWindowsWinrm.options)

module Daemons
  class EC2BootstrapCommandHandler
    def initialize(publisher = Publisher.new)
      @publisher = publisher
    end

    def handle_message(message)
      ec2_instance = AWSResource.new.find_server_by_id message["instance_id"]
      windows = ec2_instance.platform == "windows"

      bootstrap = if windows
                    Chef::Knife::BootstrapWindowsWinrm.new(message_to_windows_args(message))
                  else
                    Chef::Knife::Bootstrap.new(message_to_linux_args(message))
                  end
      bootstrap.run
      @publisher.publish(message)
    end

    private
    def message_to_linux_args(message)
      ["bootstrap",
       message["ip_address"],
       "--node-name",
       "#{message["name"]}.#{message["domain"]}",
       "--ssh-user",
       "ubuntu",
       "--sudo",
       "--environment",
       message["chef_environment"],
       "--identity-file",
       <%= @config['ssh_key_file'] %>,
       "--bootstrap-proxy",
       "http://proxy.example.com:8080",
       "--run-list",
       message["run_list"].join("'")]
    end

    def message_to_windows_args(message)
      ["bootstrap",
       "windows",
       "winrm",
       message["ip_address"],
       "--node-name",
       "#{message["name"]}.#{message["domain"]}",
       "--environment",
       message["chef_environment"],
       "--bootstrap-proxy",
       "http://proxy.example.com:8080",
       "--run-list",
       message["run_list"].join("'"),
       "--winrm-password",
       "LocalAdminPassword",
       "--winrm-user",
       "Administrator",
       "--winrm-transport",
       "plaintext"]
    end
  end
end

