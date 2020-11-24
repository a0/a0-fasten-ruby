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
      rescue StandardError => e
        log_warn "Ignoring error killing worker #{self}, error: #{e}"
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
        self.child_read, self.parent_write = IO.pipe binmode: true
        self.parent_read, self.child_write = IO.pipe binmode: true

        child_write.set_encoding 'binary'
        parent_write.set_encoding 'binary'
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
        # STDERR.puts <<~FIN
        #   --- redirect_std PID: #{$$} Thread: #{Thread.current} path: #{path} ini ---
        #     STDOUT: #{STDOUT} STDOUT&.closed?: #{STDOUT&.closed?}
        #     $stdout: #{$stdout} $stdout&.closed?: #{$stdout&.closed?}
        #     @saved_stdout_constant: #{@saved_stdout_constant} @saved_stdout_constant&.closed?: #{@saved_stdout_constant&.closed?}
        #     @redirect_log: #{@redirect_log}
        #     log_file: #{log_file}
        #     logger.logdev.filename: #{logger.instance_variable_get(:@logdev).filename}
        # FIN
        @saved_stdout_constant = STDOUT.clone
        @saved_stderr_constant = STDERR.clone

        FileUtils.mkdir_p File.dirname(path)
        @redirect_log = File.new path, 'a'
        @redirect_log.sync = true

        STDOUT.reopen @redirect_log
        STDERR.reopen @redirect_log

        logger.reopen(@redirect_log)

        # STDERR.puts <<~FIN
        #   --- redirect_std PID: #{$$} Thread: #{Thread.current} path: #{path} --- fin
        #     STDOUT: #{STDOUT} STDOUT&.closed?: #{STDOUT&.closed?}
        #     $stdout: #{$stdout} $stdout&.closed?: #{$stdout&.closed?}
        #     @saved_stdout_constant: #{@saved_stdout_constant} @saved_stdout_constant&.closed?: #{@saved_stdout_constant&.closed?}
        #     @redirect_log: #{@redirect_log}
        #     log_file: #{log_file}
        #     logger.logdev.filename: #{logger.instance_variable_get(:@logdev).filename}
        # FIN
      end

      def restore_std
        # STDERR.puts <<~FIN
        #   --- restore_std PID: #{$$} Thread: #{Thread.current} ini ---
        #     STDOUT: #{STDOUT} STDOUT&.closed?: #{STDOUT&.closed?}
        #     $stdout: #{$stdout} $stdout&.closed?: #{$stdout&.closed?}
        #     @saved_stdout_constant: #{@saved_stdout_constant} @saved_stdout_constant&.closed?: #{@saved_stdout_constant&.closed?}
        #     @redirect_log: #{@redirect_log}
        #     log_file: #{log_file}
        #     logger.logdev.filename: #{logger.instance_variable_get(:@logdev).filename}
        # FIN
        @redirect_log.close

        STDOUT.reopen @saved_stdout_constant
        STDERR.reopen @saved_stderr_constant

        @saved_stdout_constant = nil
        @saved_stderr_constant = nil

        # STDERR.puts <<~FIN
        #   --- restore_std PID: #{$$} Thread: #{Thread.current} fin ---
        #     STDOUT: #{STDOUT} STDOUT&.closed?: #{STDOUT&.closed?}
        #     $stdout: #{$stdout} $stdout&.closed?: #{$stdout&.closed?}
        #     @saved_stdout_constant: #{@saved_stdout_constant} @saved_stdout_constant&.closed?: #{@saved_stdout_constant&.closed?}
        #     @redirect_log: #{@redirect_log}
        #     log_file: #{log_file}
        #     logger.logdev.filename: #{logger.instance_variable_get(:@logdev).filename}
        # FIN
      end
    end
  end
end
