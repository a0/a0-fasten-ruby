module Fasten
  class DAG
    include Fasten::LogSupport
    attr_reader :tasks, :pending, :done

    def initialize
      @tasks = {}
      @done = []
    end

    def add(task)
      raise "Task '#{task.name}' already defined" if tasks[task.name]

      @waiting = nil
      tasks[task.name] = task
    end

    def update_task(task, **opts)
      opts.each { |key, val| task[key] = val }

      return unless task.done

      @done << task
      @pending.delete task
      task.dependants.each do |dependant_task|
        dependant_task.depends -= 1
      end

      update_waiting
    end

    def next_task
      waiting.pop
    end

    def waiting
      return @waiting if @waiting

      reset_tasks
      setup_tasks_dependencies
      @waiting = []
      update_waiting

      @waiting
    end

    protected

    def update_waiting
      move_list = @pending.select do |task|
        task.depends.zero?
      end

      @pending -= move_list
      @waiting += move_list
    end

    def reset_tasks
      @pending = []
      @done = []
      tasks.each do |_key, task|
        task.dependants = []
        task.depends = 0
        @pending << task unless task.done
        @done << task if task.done
      end
    end

    def setup_tasks_dependencies
      @pending.each do |task|
        next unless task.after

        [task.after].flatten.each do |after|
          after_task = after.is_a?(Task) ? after : tasks[after]
          raise "Dependency task '#{after}' not found on task '#{task.name}'." unless after_task

          task.depends += 1
          after_task.dependants << task
        end
      end
    end
  end
end
