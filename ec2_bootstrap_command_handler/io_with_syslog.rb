require 'syslog'
require 'syslog/logger'

class IOWithSyslog < Syslog::Logger
  def initialize(io, logger, log_severity)
    @io = io
    @logger = logger
    @log_severity = log_severity
  end

  def puts(text)
    @io.write(text)
    @logger.info(text)
  end

  def write(text)
    @io.write(text)
    @logger.info(text)
  end

  def add(_severity, message = nil, progname = nil, &block)
    @io.write(progname)
    @logger.debug(message, &block)
  end

  def sync=(_value)
    true
  end

  def sync
    true
  end
end
