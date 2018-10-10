module Fasten
  class Executor < Task
    include Fasten::LogSupport
    include Fasten::DAG

    attr_reader :task_running_list

    def initialize(name: nil, workers: 8)
      super name: name || "#{self.class} #{$PID}", workers: workers, pid: $PID, state: :IDLE, worker_list: []
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

    def perform_loop(kind: Fasten::Worker)
      loop do
        task = next_task

        wait_for_jobs task
        remove_workers_as_needed
        create_workers_as_needed kind
        worker_run_next_task task

        break if task.nil? && task_running_list.empty? && task_waiting_list.empty?
      end

      remove_all_workers
    end

    def wait_for_jobs(next_task)
      while (next_task.nil? && !task_running_list.empty?) || task_running_list.count >= workers
        reads = worker_list.map(&:parent_read)
        reads, _writes, _errors = IO.select(reads, [], [], 10)

        receive_workers_tasks(reads)
      end
    end

    def receive_workers_tasks(reads)
      reads&.each do |read|
        worker = worker_list.find { |item| item.parent_read == read }
        task = worker.receive

        update_done_task task
        log_fin task, done_stats
        task_running_list.delete task
      end
    end

    def remove_workers_as_needed
      while worker_list.count > workers
        return unless (worker = worker_list.find { |item| item.running_task.nil? })

        worker.kill
        worker_list.delete worker
      end
    end

    def create_workers_as_needed(kind)
      @worker_id ||= 0
      while worker_list.count < workers
        @worker_id += 1
        worker = kind.new name: "#{kind} #{format '%02X', @worker_id}"
        worker.fork
        worker_list << worker

        log_info "Worker created: #{worker}"
      end
    end

    def worker_run_next_task(next_task)
      return unless next_task

      worker = worker_list.find { |item| item.running_task.nil? }

      log_ini next_task
      worker.dispatch(next_task)
      task_running_list << next_task
    end

    def remove_all_workers
      while (worker = worker_list.pop)
        worker.kill
      end
    end
  end
end
