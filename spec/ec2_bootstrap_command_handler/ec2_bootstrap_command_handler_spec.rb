require 'spec_helper'
require_relative "../../ec2_bootstrap_command_handler/ec2_bootstrap_command_handler"

describe Wonga::Daemon::EC2BootstrapCommandHandler do
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
    let(:instance) { double }
    let(:address) { 'some.address' }
    let(:chef_run_completed) { "Chef Run complete" }
    let(:chef_run_failed) { "Chef Run failed!" }

    before(:each) do
      Wonga::Daemon::AWSResource.stub_chain(:new, :find_server_by_id).and_return(instance)
      instance.stub(:private_dns_name).and_return(address)
    end

    context "for linux machine" do
      before(:each) do
        instance.stub(:platform)
        Chef::Knife::Bootstrap.any_instance.stub(:run).and_return(0)
      end

      context "completes" do
        before(:each) do
          StringIO.any_instance.stub(:string).and_return(chef_run_completed)
        end

        include_examples "send message"

        it "bootstrap" do
          expect_any_instance_of(Chef::Knife::Bootstrap).to receive(:run)
          subject.handle_message message
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
        Chef::Knife::BootstrapWindowsWinrm.any_instance.stub(:run).and_return(0)
      end

      context "completes" do
        before(:each) do
          StringIO.any_instance.stub(:string).and_return(chef_run_completed)
        end

        include_examples "send message"

        it "bootstrap" do
          expect_any_instance_of(Chef::Knife::BootstrapWindowsWinrm).to receive(:run)
          subject.handle_message message
        end
      end

      context "fails to" do
        before(:each) do
          StringIO.any_instance.stub(:string).and_return(chef_run_failed)
        end
        it "bootstrap" do
          expect_any_instance_of(Chef::Knife::BootstrapWindowsWinrm).to receive(:run)
          expect{subject.handle_message message}.to raise_error(Exception)
        end
      end
    end
  end
end
