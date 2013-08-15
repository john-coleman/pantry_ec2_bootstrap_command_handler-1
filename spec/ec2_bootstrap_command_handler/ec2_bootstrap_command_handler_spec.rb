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
      "windows_admin_password" => 'Strong Password'
    }
  }

  let(:publisher) { instance_double('Wonga::Daemon::Publisher').as_null_object }
  let(:logger) { instance_double('Logger').as_null_object }
  subject(:bootstrap) { Wonga::Daemon::EC2BootstrapCommandHandler.new(publisher, logger) }

  it_behaves_like "handler"

  context "#handle_message" do
    let(:instance) { double }
    let(:address) { 'some.address' }

    before(:each) do
      Wonga::Daemon::AWSResource.stub_chain(:new, :find_server_by_id).and_return(instance)
      instance.stub(:private_dns_name).and_return(address)
    end


    context "for linux machine" do
      before(:each) do
        instance.stub(:platform)
        Chef::Knife::Bootstrap.any_instance.stub(:run) { 0 }
      end

      include_examples "send message"

      it "runs bootstrap" do
        expect_any_instance_of(Chef::Knife::Bootstrap).to receive(:run)
        subject.handle_message message
      end
    end

    context "for windows machine" do
      before(:each) do
        instance.stub(:platform).and_return('windows')
        Chef::Knife::BootstrapWindowsWinrm.any_instance.stub(:run) { 0 }
      end

      include_examples "send message"

      it "runs bootstrap" do
        expect_any_instance_of(Chef::Knife::BootstrapWindowsWinrm).to receive(:run)
        subject.handle_message message
      end
    end
  end
end
