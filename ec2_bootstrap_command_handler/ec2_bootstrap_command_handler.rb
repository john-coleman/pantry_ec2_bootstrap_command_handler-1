require 'wonga/daemon/aws_resource'
require 'chef/knife'
require 'chef/knife/bootstrap'
require 'chef/knife/bootstrap_windows_winrm'

Chef::Knife.new.configure_chef
Chef::Knife::Bootstrap.load_deps
Chef::Knife::BootstrapWindowsWinrm.load_deps

require 'chef/application/knife'
Chef::Knife::Bootstrap.options = Chef::Application::Knife.options.merge(Chef::Knife::Bootstrap.options)
Chef::Knife::BootstrapWindowsWinrm.options = Chef::Application::Knife.options.merge(Chef::Knife::BootstrapWindowsWinrm.options)

module Wonga
  module Daemon
    class EC2BootstrapCommandHandler
      def initialize(publisher, logger)
        @publisher = publisher
        Chef::Log.logger = @logger = logger
      end

      def handle_message(message)
        ec2_instance = Wonga::Daemon::AWSResource.new.find_server_by_id message["instance_id"]
        windows = ec2_instance.platform == "windows"

        bootstrap = if windows
                      @logger.info "Bootstrap using WinRM"
                      Chef::Knife::BootstrapWindowsWinrm.new(message_to_windows_args(message, ec2_instance))
                    else
                      @logger.info "Bootstrap using SSH"
                      Chef::Knife::Bootstrap.new(message_to_linux_args(message, ec2_instance))
                    end

        bootstrap.config = bootstrap.default_config.merge(bootstrap.config)
        bootstrap.run

        @publisher.publish(message)
        @logger.info "Message for instance #{message["instance_id"]} processed"
      end

      private
      def message_to_linux_args(message, ec2_instance)
        [ "bootstrap",
          message["private_ip"] || ec2_instance.private_ip_address,
          "--node-name",
          "#{message["instance_name"]}.#{message["domain"]}",
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
          message["run_list"].join("'"),
          "--verbose"
        ]
      end

      def message_to_windows_args(message, ec2_instance)
        [ "bootstrap",
          "windows",
          "winrm",
          message["private_ip"] || ec2_instance.private_ip_address,
          "--node-name",
          "#{message["instance_name"]}.#{message["domain"]}",
          "--environment",
          message["chef_environment"],
          "--bootstrap-proxy",
          "http://proxy.example.com:8080",
          "--run-list",
          message["run_list"].join("'"),
          "--winrm-password",
          message["windows_admin_password"],
          "--winrm-user",
          "Administrator",
          "--winrm-transport",
          "plaintext",
          "--verbose"
        ]
      end
    end
  end
end

