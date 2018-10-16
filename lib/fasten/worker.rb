module Fasten
  class Worker < Task
    include Fasten::LogSupport

    def initialize(executor:, name: nil)
      super executor: executor, name: name, spinner: 0
    end

    def perform(task)
      system task.shell if task.shell
    end

    def fork
      create_pipes

      self.pid = Process.fork do
        close_parent_pipes

        process_incoming_tasks
      end

      close_child_pipes
    end

    def dispatch(task)
      Marshal.dump(Task.new(task.to_h.merge(depends: nil, dependants: nil)), parent_write)
      self.running_task = task
      task.worker = self
      task.state = :RUNNING
    end

    def receive
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

    def process_incoming_tasks
      log_ini self, 'process_incoming_tasks'

      while (object = Marshal.load(child_read)) # rubocop:disable Security/MarshalLoad because pipe is a secure channel
        run_task(object) if object.is_a? Fasten::Task
      end

      log_fin self, 'process_incoming_tasks'
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
      Marshal.dump(task, child_write)
    rescue StandardError => error
      task.error = error
      Marshal.dump(task, child_write)
    end
  end
end
