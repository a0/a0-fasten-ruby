module Fasten
  class WorkerError < StandardError
    attr_reader :backtrace

    def initialize(origin)
      super "#{origin.class} #{origin.message}"
      @backtrace = origin.backtrace
    end
  end

  class Worker
    include Fasten::Logger
    include Fasten::State

    attr_accessor :executor, :name, :spinner, :child_read, :child_write, :parent_read, :parent_write, :pid, :block, :running_task

    def initialize(executor:, name: nil)
      self.executor = executor
      self.name = name
      self.spinner = 0
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
      task.state = :RUNNING
      task.worker = self
      self.running_task = task
      self.state = :RUNNING
      Marshal.dump(task, parent_write)
    end

    def receive_response
      updated_task = Marshal.load(parent_read) # rubocop:disable Security/MarshalLoad because pipe is a secure channel

      %i[state ini fin dif response error].each { |key| running_task.send "#{key}=", updated_task.send(key) }

      task = running_task
      self.running_task = self.state = nil

      task
    end

    def kill
      log_info 'Removing worker'
      Process.kill :KILL, pid
      close_parent_pipes
    rescue StandardError => error
      log_warn "Ignoring error killing worker #{self}, error: #{error}"
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
      task.state = :DONE
    rescue StandardError => error
      task.state = :FAIL
      task.error = WorkerError.new(error)
    ensure
      log_fin task, 'perform'
      send_response(task)
    end

    def send_response(task)
      log_info "Sending task response back to executor #{task}"
      data = Marshal.dump(task)
      child_write.write(data)
    end
  end
end
