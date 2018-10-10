module Fasten
  module DAG
    attr_reader :task_list, :task_done_list, :task_pending_list

    def initialize_dag
      @task_map ||= {}
      @task_list ||= []
      @task_done_list ||= []
      @task_pending_list ||= []

      nil
    end

    def add(task)
      raise "Task '#{task.name}' already defined" if @task_map[task.name]

      @task_map[task.name] = task
      @task_list << task
      @task_waiting_list = nil
    end

    def update_done_task(task)
      @task_done_list << task
      @task_pending_list.delete task
      task.dependants.each do |dependant_task|
        dependant_task.depends -= 1
      end

      move_pending_to_waiting
    end

    def next_task
      task_waiting_list.pop
    end

    def task_waiting_list
      return @task_waiting_list if @task_waiting_list

      reset_tasks
      setup_tasks_dependencies
      move_pending_to_waiting
    end

    protected

    def move_pending_to_waiting
      move_list = task_pending_list.select do |task|
        task.depends.zero?
      end

      @task_waiting_list ||= []
      @task_pending_list -= move_list
      @task_waiting_list += move_list
    end

    def reset_tasks
      @task_pending_list.clear
      @task_done_list.clear
      @task_list.each do |task|
        task.dependants = []
        task.depends = 0
        task.done ? @task_done_list << task : @task_pending_list << task
      end
    end

    def setup_tasks_dependencies
      @task_pending_list.each do |task|
        next unless task.after

        [task.after].flatten.each do |after|
          after_task = after.is_a?(Task) ? after : @task_map[after]
          raise "Dependency task '#{after}' not found on task '#{task.name}'." unless after_task

          task.depends += 1
          after_task.dependants << task
        end
      end
    end
  end
end
