module Fasten
  class Executor < Task
    include Fasten::LogSupport
    include Fasten::DAG

    attr_reader :task_running_list

    def initialize(name: nil, workers: 8, worker_class: Fasten::Worker)
      super name: name || "#{self.class} #{$PID}", workers: workers, pid: $PID, state: :IDLE, worker_class: worker_class, worker_list: []
      initialize_dag
      @task_running_list = []
    end

    def perform
      log_ini self, running_stats
      self.state = :RUNNING

      perform_loop

      self.state = :IDLE
      log_fin self, running_stats
    end

    def done_stats
      "#{task_done_list.count}/#{task_list.count}"
    end

    def running_stats
      "#{task_done_list.count + task_running_list.count}/#{task_list.count}"
    end

    def perform_loop
      loop do
        wait_for_running_tasks
        raise_error_in_failure
        remove_workers_as_needed
        dispatch_pending_tasks

        break if task_running_list.empty? && task_waiting_list.empty?
      end

      remove_all_workers
    end

    def wait_for_running_tasks
      while (task_waiting_list.empty? && !task_running_list.empty?) || task_running_list.count >= workers || (!task_running_list.empty? && !task_error_list.empty?)
        reads = worker_list.map(&:parent_read)
        reads, _writes, _errors = IO.select(reads, [], [], 10)

        receive_workers_tasks(reads)
      end
    end

    def receive_workers_tasks(reads)
      reads&.each do |read|
        worker = worker_list.find { |item| item.parent_read == read }
        task = worker.receive

        task_running_list.delete task

        update_task task

        log_fin task, done_stats
      end
    end

    def raise_error_in_failure
      return if task_error_list.empty?

      remove_all_workers

      raise "Stopping because the following #{task_error_list.count} tasks failed: #{task_error_list.map(&:to_s).join(', ')}"
    end

    def remove_workers_as_needed
      while worker_list.count > workers
        return unless (worker = worker_list.find { |item| item.running_task.nil? })

        worker.kill
        worker_list.delete worker
      end
    end

    def find_or_create_worker
      worker = worker_list.find { |item| item.running_task.nil? }

      unless worker
        @worker_id = (@worker_id || 0) + 1
        worker = worker_class.new name: "#{worker_class} #{format '%02X', @worker_id}"
        worker.fork
        worker_list << worker

        log_info "Worker created: #{worker}"
      end

      worker
    end

    def dispatch_pending_tasks
      while !task_waiting_list.empty? && task_running_list.count < workers
        worker = find_or_create_worker

        task = next_task
        log_ini task, "on worker #{worker}"
        worker.dispatch(task)
        task_running_list << task
      end
    end

    def remove_all_workers
      while (worker = worker_list.pop)
        worker.kill
      end
    end
  end
end
