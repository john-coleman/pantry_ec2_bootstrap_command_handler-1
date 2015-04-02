require_relative '../../ec2_bootstrap_command_handler/ec2_bootstrap_command_handler'
require 'wonga/daemon/aws_resource'
require 'wonga/daemon/publisher'

RSpec.describe Wonga::Daemon::EC2BootstrapCommandHandler do
  shared_examples 'skip processing instance in not valid state' do
    context 'when instance is stopped' do
      let(:status_name) { 'stopped' }

      it 'raises exception without initializing' do
        expect { subject.handle_message message }.to raise_exception
      end
    end

    context 'when instance is terminated' do
      let(:status_name) { 'terminated'  }

      it 'returns without send message' do
        subject.handle_message message
        expect(publisher).not_to have_received(:publish)
      end
    end

    context "when instance doesn't exist" do
      let(:instance) { nil }

      it 'returns without send message' do
        subject.handle_message message
        expect(publisher).not_to have_received(:publish)
      end
    end
  end

  let(:bootstrap_username) { 'CentOS' }
  let(:message) do
    {
      'pantry_request_id' => 45,
      'name' => 'myhostname',
      'domain' => 'mydomain.tld',
      'ami' => 'ami-hexidstr',
      'size' => 'aws.size1',
      'subnet_id' => 'subnet-hexidstr',
      'security_group_ids' => [
        'sg-01234567',
        'sg-89abcdef',
        'sg-7654fedc'
      ],
      'chef_environment' => 'my_team_ci',
      'run_list' => [
        'recipe[cookbook_name::specific_recipe]',
        'role[dbserver]'
      ],
      'instance_id' => 'i-0123abcd',
      'private_ip' => '100.1.1.100',
      'windows_admin_password' => 'Strong Password',
      'http_proxy' => 'http://proxy.example.com'
    }
  end
  let(:address) { 'some.address' }
  let(:aws_resource) { instance_double(Wonga::Daemon::AWSResource, find_server_by_id: instance) }
  let(:config) { {} }
  let(:error_publisher) { instance_double(Wonga::Daemon::Publisher).as_null_object }
  let(:instance) { instance_double(Aws::EC2::Instance, exists?: true, state: state, private_dns_name: address, platform: platform) }
  let(:logger) { instance_double(Logger).as_null_object }
  let(:publisher) { instance_double(Wonga::Daemon::Publisher).as_null_object }
  let(:state) { Struct.new(:name).new(status_name) }
  let(:status_name) { 'running' }
  subject(:bootstrap) { Wonga::Daemon::EC2BootstrapCommandHandler.new(publisher, error_publisher, config, aws_resource, logger) }

  context 'for linux machine' do
    before(:each) do
      allow(Chef::Knife::Bootstrap).to receive(:new).and_return(knife_bootstrap)
      expect(Chef::Knife::BootstrapWindowsWinrm).not_to receive(:new)
    end
    let(:config) { { 'version_for_linux' => '11.0-linux' } }
    let(:knife_bootstrap) { instance_double(Chef::Knife::Bootstrap, run: 0, default_config: {}, config: {}).as_null_object }
    let(:platform) { '' }

    it_behaves_like 'handler'

    context '#handle_message' do
      let(:chef_run_result) { 'Chef Run complete' }

      before(:each) do
        allow_any_instance_of(StringIO).to receive(:string).and_return(chef_run_result)
      end

      it_behaves_like 'skip processing instance in not valid state'

      include_examples 'send message'

      it 'should use Chef version for linux' do
        subject.handle_message message
        expect(Chef::Knife::Bootstrap).to have_received(:new) do |args|
          expect(args).to be_include('11.0-linux')
        end
      end

      context 'chef version is not present in config' do
        let(:config) { { 'some' => { 'test_var' => 'test_val' } } }

        it 'should not use Chef version for linux' do
          subject.handle_message message
          expect(Chef::Knife::Bootstrap).to have_received(:new) do |args|
            expect(args).to_not be_include('--bootstrap-version')
          end
        end
      end

      it 'bootstrap with default bootstrap_username' do
        subject.handle_message message
      end

      context 'with custom bootstrap username' do
        include_examples 'send message'

        it 'bootstrap with custom bootstrap_username' do
          subject.handle_message message.merge('bootstrap_username' => bootstrap_username)
          expect(Chef::Knife::Bootstrap).to have_received(:new) do |args|
            expect(args).to be_include(bootstrap_username)
            expect(args).not_to be_include('ubuntu')
          end
        end
      end

      context 'when remote chef run failed' do
        let(:chef_run_result) { 'Chef Run failed!' }

        it 'raises exception' do
          expect { subject.handle_message message }.to raise_error(Exception)
        end
      end

      context 'when chef tries to exit' do
        it 'raises internal exception and does not exit' do
          allow(knife_bootstrap).to receive(:run).and_raise(SystemExit)
          expect { subject.handle_message message }.to raise_error(Exception)
        end
      end
    end
  end

  context 'for windows machine' do
    let(:knife_bootstrap_winrm) { instance_double(Chef::Knife::BootstrapWindowsWinrm, run: 0, default_config: {}, config: {}).as_null_object }
    let(:platform) { 'windows' }

    before(:each) do
      expect(Chef::Knife::Bootstrap).to_not receive(:new)
      allow(Chef::Knife::BootstrapWindowsWinrm).to receive(:new).and_return(knife_bootstrap_winrm)
    end

    it_behaves_like 'handler'

    context '#handle_message' do
      let(:chef_run_result) { 'Chef Run complete' }

      before(:each) do
        allow_any_instance_of(StringIO).to receive(:string).and_return(chef_run_result)
      end

      it_behaves_like 'skip processing instance in not valid state'

      context 'when version for windows is provided' do
        let(:config) { { 'version_for_windows' => '11.6-windows', 'version_for_linux' => '11.0-linux' } }

        it 'uses version for windows' do
          subject.handle_message message
          expect(Chef::Knife::BootstrapWindowsWinrm).to have_received(:new) do |args|
            expect(args).to be_include('11.6-windows')
          end
        end
      end

      context 'chef version is not present in config' do
        let(:config) { { 'some' => { 'test_var' => 'test_val' } } }

        it 'should not use Chef version for linux' do
          subject.handle_message message
          expect(Chef::Knife::BootstrapWindowsWinrm).to have_received(:new) do |args|
            expect(args).to_not be_include('--bootstrap-version')
          end
        end
      end

      context 'completes' do
        include_examples 'send message'

        it 'bootstrap' do
          expect(Chef::Knife::BootstrapWindowsWinrm).to receive(:new)
          subject.handle_message message
        end
      end

      context 'fails to' do
        let(:chef_run_result) { 'Chef Run failed!' }

        it 'bootstrap' do
          expect { subject.handle_message message }.to raise_error(Exception)
        end
      end
    end
  end

  context '#handle_message publishes message to error topic for terminated instance' do
    let(:status_name) { 'terminated' }
    let(:instance) { instance_double(Aws::EC2::Instance, state: state) }

    it 'publishes message to error topic' do
      subject.handle_message(message)
      expect(error_publisher).to have_received(:publish).with(message)
    end

    it 'does not publish message to topic' do
      subject.handle_message(message)
      expect(publisher).to_not have_received(:publish)
    end
  end
end
