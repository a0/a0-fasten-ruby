require 'English'
require 'parallel'
require 'pry'

require 'fasten/support/dag'
require 'fasten/support/logger'
require 'fasten/support/state'
require 'fasten/support/stats'
require 'fasten/support/ui'
require 'fasten/support/yaml'

module Fasten
  class Runner
    include Fasten::Support::DAG
    include Fasten::Support::Logger
    include Fasten::Support::State
    include Fasten::Support::Stats
    include Fasten::Support::UI
    include Fasten::Support::Yaml

    attr_accessor :name, :workers, :worker_class, :pid, :fasten_dir, :developer, :stats, :worker_list, :block

    def initialize(name: nil, developer: STDIN.tty? && STDOUT.tty?, workers: Parallel.physical_processor_count, worker_class: Worker, fasten_dir: '.fasten')
      self.stats = name && true
      self.name = name || "#{self.class} #{$PID}"
      self.workers = workers
      self.worker_class = worker_class
      self.fasten_dir = fasten_dir
      self.developer = developer

      initialize_dag
      initialize_stats
      initialize_logger

      self.worker_list = []
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
    ensure
      save_stats
    end

    def map(list, &block)
      self.block = block

      list.each do |item|
        add Fasten::Task.new name: item.to_s, request: item
      end

      perform
      stats_table

      task_list.map(&:response)
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
        if %i[PAUSING PAUSED QUITTING].include?(state)
          check_state
        else
          dispatch_pending_tasks
        end

        break if no_running_tasks? && no_waiting_tasks? || state == :QUIT
      end

      remove_all_workers
    end

    def check_state
      if state == :PAUSING && no_running_tasks?
        self.state = :PAUSED
        ui.message = nil
        ui.force_clear
      elsif state == :QUITTING && no_running_tasks?
        self.state = :QUIT
        ui.force_clear
      end
    end

    def should_wait_for_running_tasks?
      tasks_running? && (no_waiting_tasks? || tasks_failed? || %i[PAUSING QUITTING].include?(state)) || task_running_list.count >= workers
    end

    def wait_for_running_tasks
      while should_wait_for_running_tasks?
        ui.update
        reads = worker_list.map(&:parent_read)
        reads, _writes, _errors = IO.select(reads, [], [], 0.5)

        receive_workers_tasks(reads)
      end

      ui.update
    end

    def receive_workers_tasks(reads)
      reads&.each do |read|
        next unless (worker = worker_list.find { |item| item.parent_read == read })

        task = worker.receive_response

        task_running_list.delete task

        update_task task

        log_fin task, done_counters
        ui.force_clear
      end
    end

    def show_error_tasks
      task_error_list.each do |task|
        log_info "task: #{task} error:#{task.error}\n#{task.error&.backtrace&.join("\n")}"
      end
    end

    def raise_error_in_failure
      return unless tasks_failed?

      show_error_tasks

      message = "Stopping because the following tasks failed: #{task_error_list.map(&:to_s).join(', ')}"

      if developer
        ui.cleanup
        puts message

        puts 'Entering development console'

        Kernel.binding.pry # rubocop:disable Lint/Debugger
      else
        remove_all_workers

        raise message
      end
    end

    def remove_workers_as_needed
      while worker_list.count > workers
        return unless (worker = worker_list.find { |item| item.running_task.nil? })

        worker.kill
        worker_list.delete worker

        ui.force_clear
      end
    end

    def find_or_create_worker
      worker = worker_list.find { |item| item.running_task.nil? }

      unless worker
        @worker_id = (@worker_id || 0) + 1
        worker = worker_class.new runner: self, name: "#{worker_class}-#{format '%02X', @worker_id}"
        worker.block = block if block
        worker.fork
        worker_list << worker

        log_info "Worker created: #{worker}"

        ui.force_clear
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

        ui.force_clear
      end
    end

    def remove_all_workers
      worker_list.each(&:kill)
      worker_list.clear

      ui.force_clear
    end
  end
end
