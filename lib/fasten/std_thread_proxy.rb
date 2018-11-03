module Fasten
  class StdThreadProxy
    def initialize(original)
      @original = original
    end

    def respond_to?(symbol, include_private = false)
      target = Thread.current[:FASTEN_STD_THREAD_PROXY] || @original
      target.respond_to? symbol, include_private
    end

    private

    def respond_to_missing?(name, include_private = false)
      target = Thread.current[:FASTEN_STD_THREAD_PROXY] || @original
      target.respond_to_missing? name, include_private
    end

    def method_missing(method, *args, &block) # rubocop:disable Style/MethodMissingSuper
      target = Thread.current[:FASTEN_STD_THREAD_PROXY] || @original
      target.send method, *args, &block
    end

    class << self
      def install
        return if @installed

        $stdout = StdThreadProxy.new $stdout
        $stderr = StdThreadProxy.new $stderr

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
