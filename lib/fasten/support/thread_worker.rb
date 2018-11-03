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
      rescue StandardError => error
        log_warn "Ignoring error killing worker #{self}, error: #{error}"
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
        log = File.new path, 'a'
        log.sync = true
        StdThreadProxy.thread_io = log
        logger.reopen(log)
      end

      def restore_std
        StdThreadProxy.thread_io&.close
        StdThreadProxy.thread_io = nil
        logger.reopen(log_file)
      end
    end
  end
end
