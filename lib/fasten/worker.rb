module Fasten
  class Worker < Task
    include Fasten::LogSupport

    def initialize(name: nil)
      super name: name
    end

    def perform(task)
      log_ini task, 'perform'
      system task.shell if task.shell
      log_fin task, 'perform'
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
      Marshal.dump(task, parent_write)
      self.running_task = task
    end

    def receive
      updated_task = Marshal.load(parent_read) # rubocop:disable Security/MarshalLoad

      %i[ini fin response error].each { |key| running_task[key] = updated_task[key] }

      task = running_task
      self.running_task = nil

      task
    end

    def kill
      log_info 'Removing worker'
      Process.kill(:KILL, pid)
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

    def process_incoming_tasks
      log_ini self, 'process_incoming_tasks'

      while (object = Marshal.load(child_read)) # rubocop:disable Security/MarshalLoad
        perform_task(object) if object.is_a? Fasten::Task
      end

      log_fin self, 'process_incoming_tasks'
    rescue EOFError
      log_info 'Terminating on EOF'
    end

    def perform_task(task)
      task.ini ||= Time.new
      perform(task)
      task.fin ||= Time.new
      Marshal.dump(task, child_write)
    rescue StandardError => error
      task.error = error
      Marshal.dump(task, child_write)
    end
  end
end
