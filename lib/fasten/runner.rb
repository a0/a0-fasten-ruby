require 'English'
require 'parallel'
require 'pry'
require 'os'

require 'fasten/support/dag'
require 'fasten/support/logger'
require 'fasten/support/state'
require 'fasten/support/stats'
require 'fasten/support/ui'
require 'fasten/support/yaml'
require 'fasten/timeout_queue'

module Fasten
  class Runner
    include Fasten::Support::DAG
    include Fasten::Support::Logger
    include Fasten::Support::State
    include Fasten::Support::Stats
    include Fasten::Support::UI
    include Fasten::Support::Yaml

    attr_accessor :name, :workers, :worker_class, :fasten_dir, :developer, :stats, :summary, :ui_mode, :worker_list, :use_threads, :queue

    def initialize(name: Fasten.default_name,
                   developer: Fasten.default_developer, summary: nil, ui_mode: Fasten.default_ui_mode, workers: Fasten.default_workers,
                   worker_class: Worker, fasten_dir: 'fasten', use_threads: !OS.posix?)
      reconfigure(name: name, developer: developer, summary: summary, ui_mode: ui_mode, workers: workers,
                  worker_class: worker_class, fasten_dir: fasten_dir, use_threads: use_threads)
    end

    def reconfigure(**options)
      self.stats        = options[:name] && true if options[:name] || options.key?(:stats)
      self.name         = options[:name] || "#{self.class.to_s.gsub('::', '-')}-#{$PID}" if options.key?(:name)
      self.workers      = options[:workers]       if options.key?(:workers)
      self.worker_class = options[:worker_class]  if options.key?(:worker_class)
      self.fasten_dir   = options[:fasten_dir]    if options.key?(:fasten_dir)
      self.developer    = options[:developer]     if options.key?(:developer)
      self.use_threads  = options[:use_threads]   if options.key?(:use_threads)
      self.summary      = options[:summary]       if options.key?(:summary)
      self.ui_mode      = options[:ui_mode]       if options.key?(:ui_mode)

      initialize_dag
      initialize_stats
      initialize_logger

      self.worker_list ||= []
    end

    def task(name, **opts, &block)
      add Task.new(name: name, **opts, block: block)
    end

    def register(&block)
      instance_eval(&block)
    end

    def perform
      self.state = :RUNNING
      log_ini self, running_counters
      load_stats

      run_ui do
        perform_loop
      end

      self.state = task_list.map(&:state).all?(:DONE) ? :DONE : :FAIL
      log_fin self, running_counters

      stats_add_entry(state, self)

      stats_summary if summary
    ensure
      save_stats
    end

    def map(list, &block)
      list.each do |item|
        add Fasten::Task.new name: item.to_s, request: item, block: block
      end

      perform

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
      use_threads ? wait_for_running_tasks_thread : wait_for_running_tasks_fork
    end

    def wait_for_running_tasks_thread
      self.queue ||= TimeoutQueue.new

      while should_wait_for_running_tasks?
        ui.update

        tasks = queue.receive_with_timeout(0.5)

        receive_workers_tasks_thread(tasks)
      end

      ui.update
    end

    def receive_workers_tasks_thread(tasks)
      tasks&.each do |task|
        task_running_list.delete task

        task.worker.running_task = task.worker.state = nil

        update_task task

        log_fin task, done_counters
        ui.force_clear
      end
    end

    def wait_for_running_tasks_fork
      while should_wait_for_running_tasks?
        ui.update
        reads = worker_list.map(&:parent_read)
        reads, _writes, _errors = IO.select(reads, [], [], 0.5)

        receive_workers_tasks_fork(reads)
      end

      ui.update
    end

    def receive_workers_tasks_fork(reads)
      reads&.each do |read|
        next unless (worker = worker_list.find { |item| item.parent_read == read })

        task = worker.receive_response_from_child

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
        worker = worker_class.new runner: self, name: "#{worker_class.to_s.gsub('::', '-')}-#{format '%02X', @worker_id}", use_threads: use_threads
        worker.start
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
        worker.send_request_to_child(task)
        task_running_list << task

        ui.force_clear
      end
    end

    def remove_all_workers
      worker_list.each(&:kill)
      worker_list.clear

      ui.force_clear
    end

    def kind
      'runner'
    end

    def to_s
      name
    end
  end
end
