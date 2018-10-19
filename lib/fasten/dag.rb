module Fasten
  module DAG
    attr_reader :task_map, :task_list, :task_done_list, :task_error_list, :task_pending_list, :task_running_list

    def initialize_dag
      @task_map = {}
      @task_list = []
      @task_done_list = []
      @task_error_list = []
      @task_pending_list = []
      @task_running_list = []
    end

    def add(task)
      raise "Task '#{task.name}' already defined" if @task_map[task.name]

      @task_map[task.name] = task
      @task_list << task
      @task_waiting_list = nil
    end

    def update_task(task)
      if task.state == :DONE
        update_done_task task
      else
        update_error_task task
      end

      stats_add_entry(task.state, task)
    end

    def update_done_task(task)
      @task_done_list << task
      @task_pending_list.delete task
      task.dependants.each do |dependant_task|
        dependant_task.depends.delete task
      end

      move_pending_to_waiting
    end

    def update_error_task(task)
      @task_error_list << task
      @task_pending_list.delete task
    end

    def next_task
      task_waiting_list.sort_by!(&:run_score).pop
    end

    def task_waiting_list
      return @task_waiting_list if @task_waiting_list

      reset_tasks
      setup_tasks_dependencies
      setup_tasks_scores
      move_pending_to_waiting
    end

    protected

    def move_pending_to_waiting
      move_list = task_pending_list.select do |task|
        task.depends.count.zero?
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
        task.depends = []
        task.run_score = 0
        task.done ? @task_done_list << task : @task_pending_list << task
      end
    end

    def setup_tasks_dependencies
      @task_pending_list.each do |task|
        next unless task.after

        [task.after].flatten.each do |after|
          after_task = after.is_a?(Task) ? after : @task_map[after]
          raise "Dependency task '#{after}' not found on task '#{task.name}'." unless after_task

          task.depends << after_task
          after_task.dependants << task
        end
      end
    end

    def setup_tasks_scores
      @task_pending_list.each do |task|
        task.run_score += task.dependants.count
      end
    end

    def no_waiting_tasks?
      task_waiting_list.empty?
    end

    def no_running_tasks?
      task_running_list.empty?
    end

    def tasks_waiting?
      !task_waiting_list.empty?
    end

    def tasks_running?
      !task_running_list.empty?
    end

    def tasks_failed?
      !task_error_list.empty?
    end
  end
end
