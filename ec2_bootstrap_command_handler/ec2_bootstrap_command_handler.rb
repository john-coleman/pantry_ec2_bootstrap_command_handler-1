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
require_relative 'io_with_logger'

module Wonga
  module Daemon
    class EC2BootstrapCommandHandler
      def initialize(publisher, logger)
        @publisher = publisher
        Chef::Log.logger = @logger = logger
        @logger.level = Logger::DEBUG
      end

      def handle_message(message)
        ec2_instance = Wonga::Daemon::AWSResource.new.find_server_by_id message['instance_id']
        if !ec2_instance.exists? || ec2_instance.status == :terminated
          @logger.error "Instance #{message['instance_id']} does not exist or was terminated." \
            "Pantry Request ID#{message['pantry_request_id']} #{message['instance_name']}.#{message['domain']} "
          return
        end

        fail 'Stopped' if ec2_instance.status == :stopped
        windows = ec2_instance.platform == 'windows'

        bootstrap = if windows
                      @logger.info 'Bootstrap using WinRM'
                      Chef::Knife::BootstrapWindowsWinrm.new(message_to_windows_args(message, ec2_instance))
                    else
                      @logger.info 'Bootstrap using SSH'
                      Chef::Knife::Bootstrap.new(message_to_linux_args(message, ec2_instance))
                    end

        Chef::Config[:environment] = message['chef_environment']
        bootstrap.config = bootstrap.default_config.merge(bootstrap.config)

        filthy, bootstrap_exit_code = capture_bootstrap_stdout(bootstrap) do
          bootstrap.run
        end

        if bootstrap_exit_code == 0 && (/Chef Run complete/.match(filthy) || /Chef Client finished/.match(filthy))
          @logger.info "Chef Bootstrap for instance #{message['instance_id']} completed successfully"
          @publisher.publish(message)
          @logger.info "Message for instance #{message['instance_id']} processed"
        else
          @logger.error "Chef Bootstrap for instance #{message['instance_id']} did not complete successfully"
          fail "Chef Bootstrap for instance #{message['instance_id']} did not complete successfully"
        end
      end

      def capture_bootstrap_stdout(bootstrap)
        out = StringIO.new
        logger = IOWithLogger.new(out, @logger, Logger::INFO)
        logger_error = IOWithLogger.new(out, @logger, Logger::ERROR)
        bootstrap.ui = Chef::Knife::UI.new(logger, logger_error, STDIN, {})
        Chef::Log.logger = logger
        $stdout = logger
        exit_code = yield
        return out.string, exit_code
      rescue SystemExit => se
        @logger.error "Chef bootstrap failure caused system error: #{se}"
        @logger.error se.backtrace
      ensure
        $stdout = STDOUT
        bootstrap.ui = Chef::Knife::UI.new(STDOUT, STDERR, STDIN, {})
        Chef::Log.logger = @logger
      end

      private

      def message_to_linux_args(message, ec2_instance)
        array = ['bootstrap',
                 message['private_ip'] || ec2_instance.private_ip_address,
                 '--node-name',
                 "#{message['instance_name']}.#{message['domain']}",
                 '--ssh-user',
                 message['bootstrap_username'] || 'ubuntu',
                 '--sudo',
                 '--identity-file',
                 '~/.ssh/aws-ssh-keypair.pem',
                 '--run-list',
                 message['run_list'].join(','),
                 '--verbose'
                ]
        array += ['--bootstrap-proxy', message['http_proxy']] if message['http_proxy']
        array << ['--verbose']
      end

      def message_to_windows_args(message, ec2_instance)
        array = ['bootstrap',
                 'windows',
                 'winrm',
                 message['private_ip'] || ec2_instance.private_ip_address,
                 '--node-name',
                 "#{message['instance_name']}.#{message['domain']}",
                 '--run-list',
                 message['run_list'].join(','),
                 '--winrm-password',
                 message['windows_admin_password'],
                 '--winrm-user',
                 'Administrator',
                 '--winrm-transport',
                 'plaintext',
                 '--verbose',
                 '-l',
                 'debug',
                 '--verbose'
                ]
        array += ['--bootstrap-proxy', message['http_proxy']] if message['http_proxy']
        array
      end
    end
  end
end
