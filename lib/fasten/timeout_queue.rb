module Fasten
  class TimeoutQueue
    def initialize
      @mutex = Mutex.new
      @queue = []
      @received = ConditionVariable.new
    end

    def push(object)
      @mutex.synchronize do
        @queue << object
        @received.signal
      end
    end

    def receive_with_timeout(timeout = nil) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      @mutex.synchronize do
        if timeout.nil?
          # wait indefinitely until there is an element in the queue
          @received.wait(@mutex) while @queue.empty?
        elsif @queue.empty? && timeout != 0
          # wait for element or timeout
          timeout_time = timeout + Time.now.to_f
          while @queue.empty? && (remaining_time = timeout_time - Time.now.to_f).positive?
            @received.wait(@mutex, remaining_time)
          end
        end

        items = []
        items << @queue.shift until @queue.empty?

        items
      end
    end
  end
end
