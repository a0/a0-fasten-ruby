# frozen_string_literal: true

require 'parallel'

module Fasten
  class Worker
    include ::Fasten::Support::Logger
    include ::Fasten::Support::State

    attr_accessor :runner

    def initialize(runner:)
      @runner = runner
      @fasten_dir = runner.fasten_dir
      @task_counter = 0
      @tasks = []

      state_exec!
      initialize_logger
      log_ini self, '** STARTED **'
    end

    def finalize
      state_done!
      log_fin self, "** FINALIZED ** task_counter: #{@task_counter}"
      close_logger
    end

    def max_concurrent_tasks
      @max_concurrent_tasks ||= Parallel.physical_processor_count
    end

    def perform(task)
      task.block&.call task, runner
    end

    def name = @name ||= [runner.name, self.class.to_s].join(' ')

    def receive_tasks(tasks)
      @mutex ||= Mutex.new
      @mutex.synchronize do
        max = max_concurrent_tasks
        tasks.each do |task|
          break if @tasks.count >= max

          @task_counter += 1
          @tasks.push task
          runner.take_task task
          log_info "Dispatching task max: #{max} count: #{@tasks.count} state: #{task.state} name: #{task.name}"
          dispatch_task task
        end
      end
    end

    def redirect_path(task)
      "#{runner.log_path_prefix.join("task-#{safe_name(name: task.name)}")}.log"
    end

    def redirect_std(task)
      path = redirect_path(task)
      FileUtils.mkdir_p File.dirname(path)
      task_log_file = File.new path, 'a'
      task_log_file.sync = true
      StdThreadProxy.thread_io = task_log_file
      Thread.current[:FASTEN_LOGGER] = ::Logger.new task_log_file, level: @logger.level || ::Logger::INFO, progname: $PROGRAM_NAME
    end

    def restore_std
      StdThreadProxy.thread_io&.close
      Thread.current[:FASTEN_LOGGER]&.close
    rescue StandardError
      # pass
    ensure
      StdThreadProxy.thread_io = nil
      Thread.current[:FASTEN_LOGGER] = nil
    end

    def dispatch_task(task)
      Thread.new do
        redirect_std(task)
        log_ini task, 'performing'
        task.result = perform(task)
        task.state_done!
      rescue StandardError => e
        task.state_fail!
        task.error = e
        log_error "perform error: #{e} backtrace: #{e.backtrace.first(10).join("\n")}"
      ensure
        max, count = @mutex.synchronize do
          @tasks.delete task
          runner.report_task(task)
          [max_concurrent_tasks, @tasks.count]
        end
        log_fin task, 'performed '
        restore_std
        log_info "   Reported task max: #{max} count: #{count} state: #{task.state} name: #{task.name}"
      end
    end
  end
end
