module Fasten
  class StdThreadProxy
    def initialize(original)
      @original = original
    end

    def respond_to?(name, include_private = false)
      target = Thread.current[:FASTEN_STD_THREAD_PROXY] || @original
      target.send :respond_to?, name, include_private
    end

    private

    def respond_to_missing?(name, include_private = false)
      target = Thread.current[:FASTEN_STD_THREAD_PROXY] || @original
      target.send :respond_to_missing?, name, include_private
    end

    def method_missing(method, *args, &block) # rubocop:disable MethodMissingSuper
      target = Thread.current[:FASTEN_STD_THREAD_PROXY] || @original
      target.send method, *args, &block
    end

    class << self
      def install
        return if @installed

        oldverbose = $VERBOSE
        $VERBOSE = nil
        Object.const_set :STDOUT, StdThreadProxy.new(STDOUT)
        Object.const_set :STDERR, StdThreadProxy.new(STDERR)
        $stdout = StdThreadProxy.new $stdout
        $stderr = StdThreadProxy.new $stderr

        $VERBOSE = oldverbose
        @installed = true
      end

      def thread_io=(io)
        Thread.current[:FASTEN_STD_THREAD_PROXY] = io
      end

      def thread_io
        Thread.current[:FASTEN_STD_THREAD_PROXY]
      end

      def uninstall
        return unless @installed

        @installed = nil
      end
    end
  end
end
