require 'logger'

class Wonga::Daemon::MultiLogger < Logger
  def initialize(*loggers)
    @loggers = loggers
  end

  def add(severity, message = nil, progname = nil, &block)
    @loggers.each do |logger|
      logger.add(severity, message, progname, &block)
    end
  end
end

