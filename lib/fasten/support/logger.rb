require 'binding_of_caller'
require 'fileutils'
require 'logger'

module Fasten
  class << self
    attr_accessor :logger
  end

  module Support
    module Logger
      attr_accessor :log_file, :logger

      %w[debug info error].each do |method|
        define_method "log_#{method}" do |msg|
          dest_logger = logger || Fasten.logger
          return unless dest_logger.respond_to?(method)

          caller_name = name if respond_to? :name
          caller_name ||= Kernel.binding.of_caller(1).eval('self').class
          dest_logger.send(method, caller_name) { msg }
        end
      end

      def initialize_logger(log_file: nil)
        if log_file
          self.log_file = log_file
        else
          self.log_file ||= "#{fasten_dir}/log/#{kind}/#{name}.log"
          FileUtils.mkdir_p File.dirname(self.log_file)
        end
        self.logger = ::Logger.new self.log_file, level: Fasten.logger.level, progname: Fasten.logger.progname
      end

      def log_ini(object, message = nil)
        object.ini ||= Time.new
        log_info "Ini #{object.state} #{object.class} #{object} #{message}"
      end

      def log_fin(object, message = nil)
        object.fin ||= Time.new
        object.dif = object.fin - object.ini

        log_info "Fin #{object.state} #{object.class} #{object} #{message} in #{object.dif}"
      end
    end
  end
end

Fasten.logger ||=
  begin
    Logger.new STDOUT, level: Logger::DEBUG, progname: $PROGRAM_NAME
  rescue StandardError
    nil
  end
