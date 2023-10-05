# frozen_string_literal: true

module Fasten
  class StdThreadProxy
    attr_reader :original

    def initialize(original)
      @original = original
    end

    def respond_to?(...)
      target = Thread.current[:FASTEN_STD_THREAD_PROXY] || @original
      target.send(:respond_to?, ...)
    end

    private

    def respond_to_missing?(...)
      target = Thread.current[:FASTEN_STD_THREAD_PROXY] || @original
      target.send(:respond_to_missing?, ...)
    end

    def method_missing(...)
      target = Thread.current[:FASTEN_STD_THREAD_PROXY] || @original
      target.send(...)
    end

    class << self
      def install
        return if @installed

        oldverbose = $VERBOSE
        $VERBOSE = nil

        Object.const_set :STDOUT, StdThreadProxy.new(STDOUT) # rubocop:disable Style/GlobalStdStream
        Object.const_set :STDERR, StdThreadProxy.new(STDERR) # rubocop:disable Style/GlobalStdStream

        $stdout = StdThreadProxy.new $stdout
        $stderr = StdThreadProxy.new $stderr

        @installed = true
      ensure
        $VERBOSE = oldverbose
      end

      def thread_io=(io)
        Thread.current[:FASTEN_STD_THREAD_PROXY] = io
      end

      def thread_io
        Thread.current[:FASTEN_STD_THREAD_PROXY]
      end

      def uninstall
        return unless @installed

        oldverbose = $VERBOSE
        $VERBOSE = nil

        Object.const_set :STDOUT, STDOUT.original if STDOUT.is_a? StdThreadProxy # rubocop:disable Style/GlobalStdStream
        Object.const_set :STDERR, STDERR.original if STDERR.is_a? StdThreadProxy # rubocop:disable Style/GlobalStdStream

        $stdout = $stdout.original if $stdout.is_a? StdThreadProxy
        $stderr = $stderr.original if $stderr.is_a? StdThreadProxy

        @installed = nil
      ensure
        $VERBOSE = oldverbose
      end
    end
  end
end
