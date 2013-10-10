require 'logger'

class IOWithLogger < Logger
  def initialize(io, logger, log_severity)
    @io = io
    @logger = logger
    @log_severity = log_severity
  end

  def write(text)
    @io.write(text)
    @logger.add(@log_severity, nil, text)
  end

   def add(severity, message = nil, progname = nil, &block)
     @io.write(progname)
     @logger.add(severity, message, progname, &block)
   end
end

