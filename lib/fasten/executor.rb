module Fasten
  class Executor < Task
    include Fasten::LogSupport
    include Fasten::DAG
    include Fasten::UI
    include Fasten::LoadSave
    include Fasten::Stats

    def initialize(name: nil, workers: 8, worker_class: Fasten::Worker, fasten_dir: '.fasten')
      setup_stats(name)
      super name: name || "#{self.class} #{$PID}", workers: workers, pid: $PID, state: :IDLE, worker_class: worker_class, fasten_dir: fasten_dir
      initialize_dag

      self.worker_list = []
      log_path = "#{fasten_dir}/log/executor/#{self.name}.log"
      FileUtils.mkdir_p File.dirname(log_path)
      self.log_file = File.new(log_path, 'a')
      Fasten.logger.reopen log_file
    end

    def perform
      log_ini self, running_counters
      self.state = :RUNNING
      load_stats

      run_ui do
        perform_loop
      end

      self.state = task_list.map(&:state).all?(:DONE) ? :DONE : :FAIL
      log_fin self, running_counters

      stats_add_entry(state, self)
      save_stats
    end

    def done_counters
      "#{task_done_list.count}/#{task_list.count}"
    end

    def running_counters
      "#{task_done_list.count + task_running_list.count}/#{task_list.count}"
    end

    def perform_loop
      loop do
        wait_for_running_tasks
        raise_error_in_failure
        remove_workers_as_needed
        dispatch_pending_tasks

        break if no_running_tasks? && no_waiting_tasks?
      end

      remove_all_workers
    end

    def wait_for_running_tasks
      while (no_waiting_tasks? && tasks_running?) || task_running_list.count >= workers || (tasks_running? && tasks_failed?)
        ui_update
        reads = worker_list.map(&:parent_read)
        reads, _writes, _errors = IO.select(reads, [], [], 1)

        receive_workers_tasks(reads)
      end
      ui_update
    end

    def receive_workers_tasks(reads)
      reads&.each do |read|
        next unless (worker = worker_list.find { |item| item.parent_read == read })

        task = worker.receive_response

        task_running_list.delete task

        update_task task

        log_fin task, done_counters
        self.ui_clear_needed = true
      end
    end

    def raise_error_in_failure
      return unless tasks_failed?

      task_error_list.each do |task|
        log_info "task: #{task} error:#{task.error}\n#{task.error&.backtrace&.join("\n")}"
      end

      remove_all_workers

      raise "Stopping because the following tasks failed: #{task_error_list.map(&:to_s).join(', ')}"
    end

    def remove_workers_as_needed
      while worker_list.count > workers
        return unless (worker = worker_list.find { |item| item.running_task.nil? })

        worker.kill
        worker_list.delete worker

        self.ui_clear_needed = true
      end
    end

    def find_or_create_worker
      worker = worker_list.find { |item| item.running_task.nil? }

      unless worker
        @worker_id = (@worker_id || 0) + 1
        worker = worker_class.new executor: self, name: "#{worker_class} #{format '%02X', @worker_id}"
        worker.block = block if block
        worker.fork
        worker_list << worker

        log_info "Worker created: #{worker}"

        self.ui_clear_needed = true
      end

      worker
    end

    def dispatch_pending_tasks
      while tasks_waiting? && task_running_list.count < workers
        worker = find_or_create_worker

        task = next_task
        log_ini task, "on worker #{worker}"
        worker.send_request(task)
        task_running_list << task

        self.ui_clear_needed = true
      end
    end

    def remove_all_workers
      worker_list.each(&:kill)
      worker_list.clear

      self.ui_clear_needed = true
    end
  end
end
