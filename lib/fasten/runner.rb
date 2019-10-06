require 'English'
require 'parallel'
require 'pry'
require 'os'

require 'fasten/support/logger'
require 'fasten/support/state'
require 'fasten/support/stats'
require 'fasten/support/ui'
require 'fasten/support/yaml'
require 'fasten/timeout_queue'

module Fasten
  class Runner # rubocop:disable Metrics/ClassLength
    include Fasten::Support::Logger
    include Fasten::Support::State
    include Fasten::Support::Stats
    include Fasten::Support::UI
    include Fasten::Support::Yaml

    attr_accessor :name, :stats, :summary, :jobs, :worker_class, :fasten_dir, :use_threads, :ui_mode, :developer, :workers, :queue, :tasks

    def initialize(**options)
      %i[name stats summary jobs worker_class fasten_dir use_threads ui_mode developer].each do |key|
        options[key] = Fasten.send "default_#{key}" unless options.key? key
      end

      @tasks = TaskManager.new(targets: options[:targets] || [])
      @workers = []

      reconfigure(options)
    end

    def reconfigure(**options)
      %i[name stats summary jobs worker_class fasten_dir use_threads ui_mode developer].each do |key|
        send "#{key}=", options[key] if options.key? key
      end

      initialize_stats
      initialize_logger
    end

    def task(name, **opts, &block)
      tasks << task = Task.new(name: name, **opts, block: block)

      task
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

      self.state = tasks.map(&:state).all?(:DONE) ? :DONE : :FAIL
      log_fin self, running_counters

      stats_add_entry(state, self)

      stats_summary if summary
    ensure
      save_stats
    end

    def map(list, &block)
      list.each do |item|
        task item.to_s, request: item, &block
      end

      perform

      tasks.map(&:response)
    end

    def done_counters
      "#{tasks.done.count}/#{tasks.count}"
    end

    def running_counters
      "#{tasks.done.count + tasks.running.count}/#{tasks.count}"
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

        break if tasks.no_running? && tasks.no_waiting? || state == :QUIT
      end

      remove_all_workers
    end

    def check_state
      if state == :PAUSING && tasks.no_running?
        self.state = :PAUSED
        ui.message = nil
        ui.force_clear
      elsif state == :QUITTING && tasks.no_running?
        self.state = :QUIT
        ui.force_clear
      end
    end

    def should_wait_for_running_tasks?
      tasks.running? && (tasks.no_waiting? || tasks.failed? || %i[PAUSING QUITTING].include?(state)) || tasks.running.count >= jobs
    end

    def wait_for_running_tasks
      use_threads ? wait_for_running_tasks_thread : wait_for_running_tasks_fork
    end

    def wait_for_running_tasks_thread
      self.queue ||= TimeoutQueue.new

      while should_wait_for_running_tasks?
        ui.update

        receive_jobs_tasks_thread queue.receive_with_timeout(0.5)
      end

      ui.update
    end

    def receive_jobs_tasks_thread(items)
      items&.each do |task|
        tasks.running.delete task

        task.worker.running_task = task.worker.state = nil

        tasks.update task
        stats_add_entry(task.state, task)

        log_fin task, done_counters
        ui.force_clear
      end
    end

    def wait_for_running_tasks_fork
      while should_wait_for_running_tasks?
        ui.update
        reads = workers.map(&:parent_read)
        reads, _writes, _errors = IO.select(reads, [], [], 0.5)

        receive_jobs_tasks_fork(reads)
      end

      ui.update
    end

    def receive_jobs_tasks_fork(reads)
      reads&.each do |read|
        next unless (worker = workers.find { |item| item.parent_read == read })

        task = worker.receive_response_from_child

        tasks.running.delete task

        tasks.update task
        stats_add_entry(task.state, task)

        log_fin task, done_counters
        ui.force_clear
      end
    end

    def show_error_tasks
      tasks.failed.each do |task|
        log_info "task: #{task} error:#{task.error}\n#{task.error&.backtrace&.join("\n")}"
      end
    end

    def raise_error_in_failure
      return unless tasks.failed?

      show_error_tasks

      message = "Stopping because the following tasks failed: #{tasks.failed.map(&:to_s).join(', ')}"

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
      workers.group_by(&:class).each do |_clazz, worker_list|
        while worker_list.count > jobs
          break unless (worker = workers.find { |item| item.running_task.nil? })

          worker.kill
          workers.delete worker

          ui.force_clear
        end
      end
    end

    def find_or_create_worker(worker_class:)
      worker = workers.find { |item| item.class == worker_class && item.running_task.nil? }

      unless worker
        @worker_id = (@worker_id || 0) + 1
        worker = worker_class.new runner: self, name: "#{worker_class.to_s.gsub('::', '-')}-#{format '%02X', @worker_id}", use_threads: use_threads
        worker.start
        workers << worker

        log_info "Worker created: #{worker}"

        ui.force_clear
      end

      worker
    end

    def dispatch_pending_tasks
      while tasks.waiting? && tasks.running.map(&:weight).sum < jobs
        task = tasks.next

        task_worker_class = task.worker_class || worker_class
        task_worker_class = Object.const_get(task_worker_class) if task_worker_class.is_a? String

        worker = find_or_create_worker worker_class: task_worker_class

        log_ini task, "on worker #{worker}"
        worker.send_request_to_child(task)
        tasks.running << task

        ui.force_clear
      end
    end

    def remove_all_workers
      workers.each(&:kill)
      workers.clear

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
