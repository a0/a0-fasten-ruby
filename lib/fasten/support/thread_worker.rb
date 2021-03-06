require 'fasten/std_thread_proxy'

module Fasten
  module Support
    module ThreadWorker
      attr_accessor :thread

      def start
        @queue = Queue.new

        self.thread = Thread.new do
          process_incoming_requests
        end
      end

      def kill
        log_info 'Removing worker'
        thread.exit
      rescue StandardError => e
        log_warn "Ignoring error killing worker #{self}, error: #{e}"
      ensure
        @queue.clear
      end

      def send_request_to_child(task)
        task.state = :RUNNING
        task.worker = self
        self.running_task = task
        self.state = :RUNNING

        @queue.push task
      end

      def receive_request_from_parent
        @queue.pop
      end

      def send_response_to_parent(task)
        log_info "Sending task response back to runner #{task}"

        runner.queue.push task
      end

      def redirect_std(path)
        StdThreadProxy.install

        FileUtils.mkdir_p File.dirname(path)
        @redirect_log = File.new path, 'a'
        @redirect_log.sync = true
        StdThreadProxy.thread_io = @redirect_log
        logger.reopen(@redirect_log)
      end

      def restore_std
        @redirect_log&.close
        StdThreadProxy.thread_io = nil
      end
    end
  end
end
