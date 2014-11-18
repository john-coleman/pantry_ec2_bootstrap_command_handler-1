require 'spec_helper'
require_relative "../../ec2_bootstrap_command_handler/ec2_bootstrap_command_handler"

describe Wonga::Daemon::EC2BootstrapCommandHandler do
  shared_examples "skip processing instance in not valid state" do
    context "when instance is stopped" do
      let(:instance) { instance_double('AWS::EC2::Instance', :exists? => true, status: :stopped) }

      it "raises exception without initializing" do
        expect { subject.handle_message message }.to raise_exception
      end
    end

    context "when instance is terminated" do
      let(:instance) { instance_double('AWS::EC2::Instance', :exists? => true, status: :terminated) }

      it "returns without send message" do
        subject.handle_message message
        expect(publisher).not_to have_received(:send_message)
      end
    end

    context "when instance doesn't exist" do
      let(:instance) { instance_double('AWS::EC2::Instance', :exists? => false) }

      it "returns without send message" do
        subject.handle_message message
        expect(publisher).not_to have_received(:send_message)
      end
    end
  end

  let(:bootstrap_username) { 'CentOS' }
  let(:message) {
    {
      "pantry_request_id" => 45,
      "name" => "myhostname",
      "domain" => "mydomain.tld",
      "ami" => "ami-hexidstr",
      "size" => "aws.size1",
      "subnet_id" => "subnet-hexidstr",
      "security_group_ids" => [
        "sg-01234567",
        "sg-89abcdef",
        "sg-7654fedc"
      ],
      "chef_environment" => "my_team_ci",
      "run_list" => [
        "recipe[cookbook_name::specific_recipe]",
        "role[dbserver]"
      ],
      "instance_id" => "i-0123abcd",
      "private_ip" => "10.1.1.100",
      "windows_admin_password" => 'Strong Password',
      "http_proxy" => 'http://proxy.example.com'
    }
  }

  let(:publisher) { instance_double('Wonga::Daemon::Publisher').as_null_object }
  let(:logger) { instance_double('Logger').as_null_object }
  subject(:bootstrap) { Wonga::Daemon::EC2BootstrapCommandHandler.new(publisher, logger) }

  it_behaves_like "handler"

  context "#handle_message" do
    let(:instance) { instance_double('AWS::EC2::Instance', :exists? => true, status: :running) }
    let(:address) { 'some.address' }
    let(:chef_run_completed) { "Chef Run complete" }
    let(:chef_run_failed) { "Chef Run failed!" }

    before(:each) do
      Wonga::Daemon::AWSResource.stub_chain(:new, :find_server_by_id).and_return(instance)
      allow(instance).to receive(:private_dns_name).and_return(address)
    end

    context "for linux machine" do
      before(:each) do
        instance.stub(:platform)
        Chef::Knife::Bootstrap.any_instance.stub(:run).and_return(0)
      end

      it_behaves_like "skip processing instance in not valid state"

      context "completes" do
        before(:each) do
          StringIO.any_instance.stub(:string).and_return(chef_run_completed)
          expect_any_instance_of(Chef::Knife::Bootstrap).to receive(:run)
        end

        include_examples "send message"

        it 'bootstrap with default bootstrap_username' do
          expect(Chef::Knife::Bootstrap).to receive(:new).with(bootstrap_array()).and_return(Chef::Knife::Bootstrap.new)
          subject.handle_message message
        end

        it 'bootstrap with custom bootstrap_username' do
          expect(Chef::Knife::Bootstrap).to receive(:new).with(bootstrap_array(bootstrap_username)).and_return(Chef::Knife::Bootstrap.new)
          subject.handle_message message.merge('bootstrap_username' => bootstrap_username)
        end
      end

      context "fails to" do
        before(:each) do
          StringIO.any_instance.stub(:string).and_return(chef_run_failed)
        end

        it "bootstrap" do
          expect_any_instance_of(Chef::Knife::Bootstrap).to receive(:run)
          expect{subject.handle_message message}.to raise_error(Exception)
        end

        it "bootstrap due to System exit but process does not exit" do
          Chef::Knife::Bootstrap.any_instance.stub(:run).and_raise(SystemExit)
          expect{subject.handle_message message}.to raise_error(Exception)
        end
      end

    end

    context "for windows machine" do
      before(:each) do
        instance.stub(:platform).and_return('windows')
      end

      it_behaves_like "skip processing instance in not valid state"

      context "completes" do
        before(:each) do
          expect_any_instance_of(Chef::Knife::BootstrapWindowsWinrm).to receive(:run).and_return(0)
          StringIO.any_instance.stub(:string).and_return(chef_run_completed)
        end

        include_examples "send message"

        it "bootstrap" do
          subject.handle_message message
        end
      end

      context "fails to" do
        before(:each) do
          StringIO.any_instance.stub(:string).and_return(chef_run_failed)
          expect_any_instance_of(Chef::Knife::BootstrapWindowsWinrm).to receive(:run).and_return(0)
        end

        it "bootstrap" do
          expect{subject.handle_message message}.to raise_error(Exception)
        end
      end
    end
  end

  def bootstrap_array(bootstrap_username = 'ubuntu')
    [ "bootstrap",
      message["private_ip"],
      "--node-name",
      "#{message["instance_name"]}.#{message["domain"]}",
      "--ssh-user",
      bootstrap_username,
      "--sudo",
      "--identity-file",
      <%= @config['ssh_key_file'] %>,
      "--run-list",
      message["run_list"].join(","),
      "--verbose",
      "--bootstrap-proxy",
      message["http_proxy"],
      ["--verbose"]
    ]
  end
end
