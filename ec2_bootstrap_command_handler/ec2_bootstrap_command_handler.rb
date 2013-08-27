require 'wonga/daemon/aws_resource'
require 'chef/knife'
require 'chef/knife/bootstrap'
require 'chef/knife/bootstrap_windows_winrm'
require 'stringio'

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
        @logger.level = Logger::DEBUG
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

        Chef::Config[:environment] = message["chef_environment"]
        bootstrap.config = bootstrap.default_config.merge(bootstrap.config)

        filthy, bootstrap_exit_code = capture_bootstrap_stdout do
		  begin
			bootstrap.run
		  rescue SystemExit => se
			@logger.error "Chef bootstrap failure caused system error: #{se}"
		  end
        end

        if bootstrap_exit_code == 0 && /Chef Run complete/.match(filthy.string)
          @logger.info "Chef Bootstrap for instance #{message["instance_id"]} completed successfully"
          @publisher.publish(message)
          @logger.info "Message for instance #{message["instance_id"]} processed"
        else
          @logger.error "Chef Bootstrap for instance #{message["instance_id"]} did not complete successfully"
          raise "Chef Bootstrap for instance #{message["instance_id"]} did not complete successfully"
        end
      end

      def capture_bootstrap_stdout
        out = StringIO.new
        $stdout = out
        exit_code = yield
        return out, exit_code
      ensure
        $stdout = STDOUT
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

