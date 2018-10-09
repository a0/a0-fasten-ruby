module Fasten
  class Executor < Task
    include Fasten::LogSupport

    def initialize(name: nil, workers: 8)
      super name: name || $PROGRAM_NAME
      self.workers = workers

      self.pid = $PID
      self.dag = Fasten::DAG.new
      self.running = false
      self.children = {}
      self.running_tasks = []
    end

    def add(task)
      dag.add task
    end

    def perform
      log_ini self
      self.ini = Time.new
      self.running = true

      perform_loop

      self.fin = Time.new
      log_fin self
    end

    protected

    def log_ini(object)
      log_info "Init #{dag.done.count + running_tasks.count}/#{dag.tasks.count} #{object.class} #{object}"
    end

    def log_fin(object)
      log_info "Done #{dag.done.count}/#{dag.tasks.count} #{object.class} #{object} in #{object.fin - object.ini}"
    end

    def perform_loop
      while running
        next_task = dag.next_task

        wait_children next_task
        run_next_task next_task

        self.running = !(next_task.nil? && children.empty? && dag.waiting.empty?)
      end

      wait_remaining
    end

    def wait_children(next_task)
      return unless (next_task.nil? && !children.empty?) || children.count >= workers

      pid = Process.wait(0)
      done_task = children.delete pid
      return unless done_task

      dag.update_task done_task, done: true, fin: Time.new
      running_tasks.delete done_task

      log_fin done_task
    end

    def run_next_task(next_task)
      return unless next_task

      running_tasks << next_task
      log_ini next_task

      next_task.ini = Time.new
      pid = fork do
        next_task.perform
      end
      children[pid] = next_task
    end

    def wait_remaining
      children.each do |child_pid, child_task|
        Process.wait child_pid
        dag.update_task child_task, done: true
      end
    end
  end
end
