module Fasten
  module Support
    module ForkWorker
      attr_accessor :pid

      def start
        create_pipes

        self.pid = Process.fork do
          close_parent_pipes

          process_incoming_requests
        end

        close_child_pipes
      end

      def kill
        log_info 'Removing worker'
        Process.kill :KILL, pid
      rescue StandardError => error
        log_warn "Ignoring error killing worker #{self}, error: #{error}"
      ensure
        close_parent_pipes
        close_child_pipes
      end

      def send_request_to_child(task)
        task.state = :RUNNING
        task.worker = self
        self.running_task = task
        self.state = :RUNNING

        Marshal.dump(task, parent_write)
      end

      def receive_response_from_child
        updated_task = Marshal.load(parent_read) # rubocop:disable Security/MarshalLoad because pipe is a secure channel

        %i[state ini fin dif response error].each { |key| running_task.send "#{key}=", updated_task.send(key) }

        task = running_task
        self.running_task = self.state = nil

        task
      end

      def receive_request_from_parent
        Marshal.load(child_read) # rubocop:disable Security/MarshalLoad because pipe is a secure channel
      end

      def send_response_to_parent(task)
        log_info "Sending task response back to runner #{task}"

        data = Marshal.dump(task)
        child_write.write(data)
      end

      def create_pipes
        self.child_read, self.parent_write = IO.pipe
        self.parent_read, self.child_write = IO.pipe
      end

      def close_parent_pipes
        parent_read.close unless parent_read.closed?
        parent_write.close unless parent_write.closed?
      end

      def close_child_pipes
        child_read.close unless child_read.closed?
        child_write.close unless child_write.closed?
      end

      def redirect_std(path)
        logger.reopen($stdout)

        @saved_stdout_instance = $stdout.clone
        @saved_stderr_instance = $stderr.clone
        @saved_stdout_constant = STDOUT.clone
        @saved_stderr_constant = STDERR.clone

        FileUtils.mkdir_p File.dirname(path)
        @redirect_log = File.new path, 'a'
        @redirect_log.sync = true

        $stdout.reopen @redirect_log
        $stderr.reopen @redirect_log
        STDOUT.reopen @redirect_log
        STDERR.reopen @redirect_log
      end

      def restore_std
        $stdout = @saved_stdout_instance
        $stderr = @saved_stderr_instance
        Object.const_set :STDOUT, @saved_stdout_constant
        Object.const_set :STDERR, @saved_stderr_constant

        @redirect_log.close
      end
    end
  end
end
