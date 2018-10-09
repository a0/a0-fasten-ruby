module Fasten
  class << self
    attr_accessor :logger
  end

  module LogSupport
    %w[debug info error].each do |method|
      define_method "log_#{method}" do |msg|
        return unless Fasten.logger.respond_to?(method)

        caller = Kernel.binding.of_caller(1).eval('self')
        Fasten.logger.send(method, caller.class) { msg }
      end
    end
  end
end

Fasten.logger ||=
  begin
    Logger.new(STDOUT, level: Logger::INFO, progname: $PROGRAM_NAME)
  rescue StandardError
    nil
  end
