module Fasten
  class WorkerError < StandardError
    attr_reader :backtrace
    def initialize(origin)
      super "#{origin.class} #{origin.message}"
      @backtrace = origin.backtrace
    end
  end

  class Worker < Task
    include Fasten::LogSupport

    def initialize(executor:, name: nil)
      super executor: executor, name: name, spinner: 0
    end

    def perform(task)
      perform_shell(task) if task.shell
      perform_ruby(task) if task.ruby
      perform_block(task) if block
    end

    def perform_ruby(task)
      task.response = eval task.ruby # rubocop:disable Security/Eval we trust our users ;-)
    end

    def perform_shell(task)
      result = system task.shell

      raise "Command failed with exit code: #{$CHILD_STATUS.exitstatus}" unless result
    end

    def perform_block(task)
      task.response = block.call(task.request)
    end

    def fork
      create_pipes

      self.pid = Process.fork do
        close_parent_pipes

        process_incoming_requests
      end

      close_child_pipes
    end

    def send_request(task)
      Marshal.dump(Task.new(task.to_h.merge(depends: nil, dependants: nil)), parent_write)
      self.running_task = task
      task.worker = self
      task.state = :RUNNING
    end

    def receive_response
      updated_task = Marshal.load(parent_read) # rubocop:disable Security/MarshalLoad because pipe is a secure channel

      %i[ini fin response error].each { |key| running_task[key] = updated_task[key] }

      task = running_task
      self.running_task = nil
      task.state = task.error ? :FAIL : :DONE

      task
    end

    def kill
      log_info 'Removing worker'
      Process.kill(:KILL, pid)
      close_parent_pipes
    rescue StandardError => error
      log_warn "Ignoring error killing worker #{self}, error: #{error}"
    end

    def idle?
      running_task.nil?
    end

    def running?
      !idle?
    end

    protected

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

    def process_incoming_requests
      log_ini self, 'process_incoming_requests'

      while (object = Marshal.load(child_read)) # rubocop:disable Security/MarshalLoad because pipe is a secure channel
        run_task(object) if object.is_a? Fasten::Task
      end

      log_fin self, 'process_incoming_requests'
    rescue EOFError
      log_info 'Terminating on EOF'
    end

    def run_task(task)
      log_ini task, 'perform'
      Fasten.logger.reopen(STDOUT)
      redirect_std "#{executor.fasten_dir}/log/task/#{task.name}.log"

      perform_task task

      restore_std
      Fasten.logger.reopen(executor.log_file)
      log_fin task, 'perform'
    end

    def perform_task(task)
      log_ini task, 'perform'

      perform(task)

      log_fin task, 'perform'
      send_response(task)
    rescue StandardError => error
      task.error = WorkerError.new(error)
      send_response(task)
    end

    def send_response(task)
      log_info "Sending task response back to executor #{task}"
      begin
        data = Marshal.dump(task)
      rescue StandardError
        task.error = RuntimeError.new(task.error.message + "\n#{task.error.backtrace&.join("\n")}")
        data = Marshal.dump(task)
      end
      child_write.write(data)
    end
  end
end
