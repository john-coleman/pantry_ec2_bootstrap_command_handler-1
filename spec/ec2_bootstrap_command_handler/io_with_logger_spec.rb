require 'spec_helper'
require_relative '../../ec2_bootstrap_command_handler/io_with_logger'
require 'logger'

describe IOWithLogger do
  let(:string_io) { instance_double('StringIO').as_null_object }
  let(:logger) { instance_double('Logger').as_null_object }
  let(:message_type) { :info }

  subject { described_class.new(string_io, logger, message_type) }

  describe "#puts" do
    it "writes to string io" do
      subject.puts('text')
      expect(string_io).to have_received(:write).with('text')
    end

    it "logs to logger" do
      subject.puts('text')
      expect(logger).to have_received(:add).with(message_type, nil, 'text')
    end
  end

  describe "#write" do
    it "writes to string io" do
      subject.write('text')
      expect(string_io).to have_received(:write).with('text')
    end

    it "logs to logger" do
      subject.write('text')
      expect(logger).to have_received(:add).with(message_type, nil, 'text')
    end
  end

  describe "#info" do
    it "writes to string io" do
      subject.info('text')
      expect(string_io).to have_received(:write).with('text')
    end

    it "logs to logger" do
      subject.write('text')
      expect(logger).to have_received(:add).with(:info, nil, 'text')
    end
  end
end

