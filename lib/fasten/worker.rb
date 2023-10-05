# frozen_string_literal: true

require 'parallel'

module Fasten
  class Worker
    include ::Fasten::Support::Logger

    attr_accessor :runner

    def initialize(runner:)
      @runner = runner
      @fasten_dir = runner.fasten_dir
      @task_counter = 0
      @tasks = []

      initialize_logger
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
        tasks.each do |task|
          break if @tasks.count >= max_concurrent_tasks

          @task_counter += 1
          @tasks.push task
          runner.take_task task
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
      @redirect_log = File.new path, 'a'
      @redirect_log.sync = true
      StdThreadProxy.thread_io = @redirect_log
      Thread.current[:FASTEN_LOGGER] = ::Logger.new path, level: @logger.level || ::Logger::INFO, progname: $PROGRAM_NAME
    end

    def restore_std
      @redirect_log&.close
      StdThreadProxy.thread_io = nil
      Thread.current[:FASTEN_LOGGER] = nil
    end

    def dispatch_task(task)
      log_info "Dispatching task name: #{task.name}"
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
        @mutex.synchronize do
          @tasks.delete task
          runner.report_task(task)
        end
        log_fin task, 'performed '
        restore_std
      end
    end
  end
end
