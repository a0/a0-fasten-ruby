module Fasten
  class StdThreadProxy
    attr_reader :fasten_original

    def initialize(fasten_original)
      @fasten_original = fasten_original
    end

    def respond_to?(*args)
      target = Thread.current[:FASTEN_STD_THREAD_PROXY] || @fasten_original
      target.send :respond_to?, *args
    end

    private

    def respond_to_missing?(*args)
      target = Thread.current[:FASTEN_STD_THREAD_PROXY] || @fasten_original
      target.send :respond_to_missing?, *args
    end

    def method_missing(method, *args, &block)
      target = Thread.current[:FASTEN_STD_THREAD_PROXY] || @fasten_original
      target.send method, *args, &block
    rescue StandardError => e
      raise e
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

        Object.const_set :STDOUT, STDOUT.fasten_original if STDOUT.is_a? StdThreadProxy # rubocop:disable Style/GlobalStdStream
        Object.const_set :STDERR, STDERR.fasten_original if STDERR.is_a? StdThreadProxy # rubocop:disable Style/GlobalStdStream

        $stdout = $stdout.fasten_original if $stdout.is_a? StdThreadProxy
        $stderr = $stderr.fasten_original if $stderr.is_a? StdThreadProxy

        @installed = nil
      ensure
        $VERBOSE = oldverbose
      end
    end
  end
end
