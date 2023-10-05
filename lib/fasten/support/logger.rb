# frozen_string_literal: true

require 'binding_of_caller'
require 'fileutils'
require 'logger'

module Fasten
  class << self
    attr_accessor :logger
  end

  module Support
    module Logger
      attr_accessor :log_file, :log_level, :name

      %w[debug info error].each do |method|
        define_method "log_#{method}" do |msg|
          return unless logger.respond_to?(method)

          caller_name = name if respond_to? :name
          caller_name ||= Kernel.binding.of_caller(1).eval('self').class
          logger.send(method, caller_name) { msg }
        end
      end

      def initialize_logger(log_file: log_default_file)
        self.log_file = log_file
        FileUtils.mkdir_p File.dirname(log_file)

        # close_logger
        @logger = ::Logger.new self.log_file, level: log_level || ::Logger::INFO, progname: $PROGRAM_NAME

        Fasten.logger.debug "Logger created class: #{log_class} log_file: #{self.log_file}"
      end

      def logger
        Thread.current[:FASTEN_LOGGER] || @logger || Fasten.logger
      end

      def log_ini(object, message = nil)
        object.ini ||= Time.new
        log_info "ini state: #{object.state} #{object.class} name: #{object.name} #{message}"
      end

      def log_fin(object, message = nil)
        object.fin ||= Time.new
        object.dif = object.fin - object.ini
        log_info "FIN state: #{object.state} #{object.class} name: #{object.name} #{message} in #{object.dif}"
      end

      def close_logger
        puts "Closing logger #{logger}"
        logger.close if logger.is_a? ::Logger
      end

      def log_default_file
        "#{log_path_prefix}.log"
      end

      def log_class
        is_a?(Class) ? self : self.class
      end

      def log_path_prefix
        fasten_log_dir.join("#{log_class.to_s.split('::').last.downcase}-#{safe_name}")
      end

      def fasten_log_dir
        @fasten_dir ||= ::Fasten::DEFAULT_FASTEN_DIR
        Pathname.new(@fasten_dir).join('log')
      end

      def safe_name(name: self.name)
        name.strip.delete('.').delete('/').tr(' ', '_').gsub('__', '_')
      end
    end
  end
end

Fasten.logger ||=
  begin
    Logger.new $stdout, level: Logger::INFO, progname: $PROGRAM_NAME
  rescue StandardError
    nil
  end
