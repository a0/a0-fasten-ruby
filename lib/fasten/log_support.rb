module Fasten
  class << self
    attr_accessor :logger
  end

  module LogSupport
    %w[debug info error].each do |method|
      define_method "log_#{method}" do |msg|
        return unless Fasten.logger.respond_to?(method)

        caller_name = name if respond_to? :name
        caller_name ||= Kernel.binding.of_caller(1).eval('self').class
        Fasten.logger.send(method, caller_name) { msg }
      end
    end

    def log_ini(object, message = nil)
      object.ini ||= Time.new
      log_info "Init #{object.class} #{object} #{message}"
    end

    def log_fin(object, message = nil)
      object.fin ||= Time.new
      object.dif = object.fin - object.ini

      log_info "Done #{object.class} #{object} #{message} in #{object.dif}"
    end

    def redirect_std(path)
      @saved_stdout = $stdout.clone
      @saved_stderr = $stderr.clone

      FileUtils.mkdir_p File.dirname(path)
      log = File.new path, 'a'
      log.sync = true

      $stdout.reopen log
      $stderr.reopen log
    end

    def restore_std
      $stdout.reopen(@saved_stdout)
      $stderr.reopen(@saved_stderr)
    end
  end
end

Fasten.logger ||=
  begin
    Logger.new(STDOUT, level: Logger::DEBUG, progname: $PROGRAM_NAME)
  rescue StandardError
    nil
  end
