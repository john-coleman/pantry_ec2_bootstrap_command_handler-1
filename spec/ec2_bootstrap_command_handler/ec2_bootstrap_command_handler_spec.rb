require_relative '../../ec2_bootstrap_command_handler/ec2_bootstrap_command_handler'

RSpec.describe Wonga::Daemon::EC2BootstrapCommandHandler do
  shared_examples 'skip processing instance in not valid state' do
    context 'when instance is stopped' do
      let(:instance) { instance_double('AWS::EC2::Instance', :exists? => true, status: :stopped) }

      it 'raises exception without initializing' do
        expect { subject.handle_message message }.to raise_exception
      end
    end

    context 'when instance is terminated' do
      let(:instance) { instance_double('AWS::EC2::Instance', :exists? => true, status: :terminated) }

      it 'returns without send message' do
        subject.handle_message message
        expect(publisher).not_to have_received(:send_message)
      end
    end

    context "when instance doesn't exist" do
      let(:instance) { instance_double('AWS::EC2::Instance', :exists? => false) }

      it 'returns without send message' do
        subject.handle_message message
        expect(publisher).not_to have_received(:send_message)
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
      'private_ip' => '10.1.1.100',
      'windows_admin_password' => 'Strong Password',
      'http_proxy' => 'http://proxy.example.com'
    }
  end
  let(:knife_bootstrap) { instance_double(Chef::Knife::Bootstrap, run: 0, default_config: {}, config: {}).as_null_object }

  let(:publisher) { instance_double('Wonga::Daemon::Publisher').as_null_object }
  let(:logger) { instance_double('Logger').as_null_object }
  subject(:bootstrap) { Wonga::Daemon::EC2BootstrapCommandHandler.new(publisher, logger) }

  it_behaves_like 'handler'

  context '#handle_message' do
    let(:instance) { instance_double('AWS::EC2::Instance', :exists? => true, status: :running) }
    let(:address) { 'some.address' }
    let(:chef_run_result) { 'Chef Run complete' }

    before(:each) do
      allow(Wonga::Daemon::AWSResource).to receive_message_chain(:new, :find_server_by_id).and_return(instance)
      allow(instance).to receive(:private_dns_name).and_return(address)
      allow_any_instance_of(StringIO).to receive(:string).and_return(chef_run_result)
    end

    context 'for linux machine' do
      before(:each) do
        allow(instance).to receive(:platform)
        allow(Chef::Knife::Bootstrap).to receive(:new).and_return(knife_bootstrap)
      end

      it_behaves_like 'skip processing instance in not valid state'

      include_examples 'send message'

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

    context 'for windows machine' do
      before(:each) do
        allow(instance).to receive(:platform).and_return('windows')
        allow_any_instance_of(Chef::Knife::BootstrapWindowsWinrm).to receive(:run).and_return(0)
      end

      it_behaves_like 'skip processing instance in not valid state'

      context 'completes' do
        include_examples 'send message'

        it 'bootstrap' do
          expect_any_instance_of(Chef::Knife::BootstrapWindowsWinrm).to receive(:run).and_return(0)
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
end
